# Spire — Estratégia de Validação e Versionamento de APIs

**Status:** Proposta. Em revisão.
**Data:** 2026-08-26
**Origina:** Análise de ferramentas pós EXP-006

---

## Contexto

Hoje o Spire valida artefatos de API **client-side** (via `spire-submit.sh`):
schema básico do `catalog-info.yaml`, presença do `openapi.yaml` e seções obrigatórias
do OBC. Isso é necessário mas insuficiente para:

1. **Validação de qualidade da spec** — a spec é sintaticamente válida, mas viola boas
   práticas? Tem paths sem operationId? Respostas de erro sem schema?
2. **Detecção de breaking changes** — uma nova versão da spec quebra consumidores
   existentes? Quem é avisado? Quando?
3. **Versionamento de contratos** — onde ficam as versões históricas da spec? Do OBC?
   Como um consumidor descobre que o contrato de um serviço mudou?
4. **Validação em runtime** — o serviço respeita a própria spec em produção?

Esta estratégia define o modelo para cada um desses problemas.

---

## Toolchain Proposta

### Mapa de ferramentas por estágio

AsyncAPI é **opcional** — um serviço pode ter OpenAPI, AsyncAPI, ambos ou nenhum.
O que determina o nível de governança é o OBC, não a presença de spec de API.

```
ESTÁGIO        ARTEFATO           FERRAMENTA              OBRIGATÓRIO?
────────────────────────────────────────────────────────────────────────────
Submissão      catalog-info.yaml  Plugin interno           SIM — bloqueia
               OBC (*.md)         Plugin interno           SIM — bloqueia
               openapi.yaml       Spectral + oasdiff       NÃO — se presente
               asyncapi.yaml      asyncapi/cli + Spectral  NÃO — se presente
               slo.yaml           oslo validate            NÃO — se presente

Runtime        OpenAPI → Kong     request-validator        Apenas se openapi.yaml
               AsyncAPI → Microcks mock/conformance        Apenas se asyncapi.yaml

Versionamento  OpenAPI            Apicurio (compat. rules) Apenas se openapi.yaml
               AsyncAPI           Apicurio (sem compat.)   Apenas se asyncapi.yaml

Documentação   Qualquer spec      Backstage API plugin     Apenas se spec presente
               Versões            Apicurio Backstage plg   Apenas se spec presente
```

### Lógica de detecção no Governance Plugin

```typescript
const hasOpenAPI  = fs.existsSync('api/openapi.yaml')
const hasAsyncAPI = fs.existsSync('api/asyncapi.yaml')
const hasSLO      = fs.existsSync('slo.yaml')

if (hasOpenAPI)  await validateOpenAPI(spec)   // Spectral + oasdiff + Apicurio + Kong
if (hasAsyncAPI) await validateAsyncAPI(spec)  // asyncapi/cli + Spectral:asyncapi + Apicurio + Microcks
if (hasSLO)      await validateSLO(spec)       // oslo validate (advisory — não bloqueia)
if (!hasOpenAPI && !hasAsyncAPI) report.warn('no-spec', 'Nenhuma spec de API detectada')
```

---

## Ferramentas: Decisão e Justificativa

### Spectral — Linting de OpenAPI

**O que faz:** Valida OpenAPI (e AsyncAPI) contra rulesets customizáveis. Rules cobrem
estilo, completude, operationIds, respostas obrigatórias, segurança, formatos.

**Por que no Spire:**
- Permite que o Spire defina um ruleset próprio (`spire-spectral-ruleset.yaml`) que
  encapsula as regras de governança que toda spec submetida deve obedecer.
- Roda em CI antes do `spire-submit.sh` — spec inválida não chega ao Backstage.
- Integra no `spire-submit.sh` como etapa 0 (antes da validação atual).

**Escopo de regras sugerido para v1:**
```yaml
# spire-spectral-ruleset.yaml
rules:
  operation-id-required:       error   # todo path/method deve ter operationId
  response-error-schema:       warn    # 4xx/5xx devem ter schema de erro
  info-contact:                warn    # info.contact preenchido
  no-eval-in-markdown:         error   # segurança
  paths-kebab-case:            warn    # consistência de naming
```

---

### oasdiff — Detecção de Breaking Changes

**O que faz:** Compara duas versões de OpenAPI e produz lista de breaking changes
(remoção de path, mudança de tipo obrigatório, remoção de campo, etc.).

**Por que no Spire:**
- Integra como gate no CI: se a nova spec quebra o contrato, o pipeline falha —
  a menos que o autor eleve a major version intencionalmente.
- Output em JSON → consumível pelo `spire-submit.sh` para gerar relatório de diff.
- Liga diretamente ao versionamento: `oasdiff` decide se é patch, minor ou major.

**Regra de versionamento automático baseado em oasdiff:**
```
oasdiff breaking  → major version obrigatória (x.0.0)
oasdiff non-breaking changes → minor ou patch (decisão do autor)
sem diff          → patch automático (script pode auto-incrementar)
```

---

### Apicurio Registry — Registro de Contratos e Schemas

**O que faz:** Registry open-source (Red Hat, Apache 2.0) que armazena e versiona
OAS3, AsyncAPI, Avro, Protobuf e JSON Schema. Expõe REST API, tem Backstage plugin
e suporte a regras de compatibilidade (backward/forward/full).

**Por que no Spire — é o componente mais importante desta estratégia:**

1. **Fonte de verdade para versões de spec** — não o repositório Git nem o Backstage
   catalog. O Git tem a spec do momento, o Apicurio tem o histórico completo com
   versões semânticas.
2. **Breaking change gate** — `oasdiff` compara a spec nova com a versão atual
   buscada do Apicurio via REST. Sem Apicurio, não há versão de referência para diff.
3. **Backstage plugin** — `@apicurio/backstage-plugin-apicurio-registry` renderiza
   versões de spec diretamente no catalog. Tech lead vê v1.2.0 vs v2.0.0 no Backstage.
4. **AsyncAPI nativo** — quando o Spire suportar serviços event-driven, o Apicurio
   armazena as specs AsyncAPI com as mesmas APIs de versioning.

**Integração no fluxo de submissão:**
```
spire-submit.sh
  └─ 0. Spectral lint
  └─ 1. Busca versão atual no Apicurio (GET /apis/{groupId}/{artifactId}/versions/latest)
  └─ 2. oasdiff: nova spec vs versão atual
  └─ 3. Se breaking → exige version bump major
  └─ 4. POST spec no Apicurio (nova versão registrada)
  └─ 5. POST catalog/locations no Backstage (como hoje)
```

---

### Kong request-validator — Validação em Runtime

**O que faz:** Plugin nativo do Kong (open-source) que valida requests contra JSON Schema
antes de encaminhar ao backend. Bloqueia requests com body inválido com HTTP 400.

**Por que no Spire:**
- Kong já está no critical path de toda request. Adicionar `request-validator` não
  requer novo componente.
- O schema de validação pode ser extraído da spec OpenAPI e injetado na configuração
  do Kong durante o `spire-submit.sh` (nova capability: geração de Kong config a partir
  da spec).
- Isto fecha o loop: a spec que o Spire registra passa a ser enforçada em runtime —
  não apenas documentada.

**Limitação:** o plugin não valida responses (apenas requests). Para response validation
em dev/staging, usar Prism como proxy.

---

### Prism — Validação de Response e Mocking (dev)

**O que faz:** Proxy HTTP que valida responses do serviço real contra a spec OpenAPI.
Em modo mock, gera responses a partir da spec sem precisar do backend real.

**Por que no Spire:**
- Roda como sidecar em ambientes de dev/staging; não entra em produção.
- Fecha o gap do Kong request-validator: Kong valida entrada, Prism valida saída.
- Substitui mocks manuais durante desenvolvimento de novos serviços.

---

### Pact Broker — Consumer-Driven Contracts

**O que faz:** Consumidores publicam contratos (Pact files); providers verificam.
Broker centraliza versões de contrato e expõe `can-i-deploy` para CI.

**Por que no Spire — apenas quando houver múltiplos serviços integrados:**
- Torna explícita a dependência de contrato entre `service A` (consumer) e
  `service B` (provider) — independente do que a spec do provider diz.
- Backlog: integrar Pact Broker como componente do Spire quando ≥ 2 serviços
  governados com dependências entre si.

---

### Microcks — AsyncAPI e Mocking de Eventos

**O que faz:** Mock + contract testing para REST, AsyncAPI (Kafka, AMQP, MQTT).
CNCF Sandbox, Backstage plugin disponível.

**Por que no Spire:**
- Quando serviços event-driven forem governados pelo Spire, Microcks é o equivalente
  do Prism para eventos — mock de topics Kafka a partir de AsyncAPI spec.
- Backlog até que haja serviços event-driven registrados.

---

## Versionamento de Contratos

### APIs (OpenAPI / AsyncAPI) — Semver via Apicurio

```
MAJOR.MINOR.PATCH

MAJOR — mudança breaking (remover path, mudar tipo obrigatório, remover campo)
         detectado por oasdiff → gate bloqueia sem bump explícito
         Requer: novo Business Intent + novo OBC major

MINOR — adição backward-compatible (novo path, novo campo opcional)
         oasdiff classifica como non-breaking

PATCH — correção de descrição, exemplo, formato de documentação
         sem impacto em comportamento do serviço
```

**Onde vive:** Apicurio Registry é a fonte de verdade. O `openapi.yaml` no repositório
representa a versão corrente; o histórico está no Apicurio.

**Referência no catalog-info.yaml:**
```yaml
metadata:
  annotations:
    apicurio.io/registry-url: https://apicurio.spire.local
    apicurio.io/artifact-id: payments-api
    apicurio.io/group-id: spire
```

---

### OBCs (Observable Business Contracts) — Semver no frontmatter

OBCs são documentos Markdown versionados via Git, mas precisam de versão semântica
explícita para que o Spire possa detectar breaking changes de contrato.

**Estrutura de versão no OBC:**

```markdown
# OBC — [capability-name]

version: 1.2.0
status: Operational
changelog:
  - 2.0.0: Breaking — Observable Event `payment.created` renomeado para `payment.initiated`
  - 1.2.0: Minor — novo SLI de latência p99
  - 1.1.0: Minor — novo Observable Event `payment.refunded`
  - 1.0.0: Initial
```

**Regras de versionamento do OBC:**

| Mudança | Impacto | Version bump |
|---|---|---|
| Observable Event renomeado ou removido | Breaking — consumidores param de receber o evento | MAJOR |
| Response Contract: campo obrigatório removido ou mudança de tipo | Breaking | MAJOR |
| Novo Observable Event adicionado | Additive | MINOR |
| Novo SLI adicionado | Additive | MINOR |
| Reliability Rule atualizada | Additive | MINOR |
| Correção de texto, exemplo, descrição | Nenhum | PATCH |

**MAJOR OBC = novo Business Intent obrigatório** — uma mudança breaking de contrato
de negócio presupõe uma nova intenção de produto que justifique a ruptura.

---

## Arquitetura Expandida (com Apicurio)

```
spire-submit.sh
    ↓
Spectral lint                          ← NOVO (linting de qualidade)
    ↓
Busca versão atual (Apicurio REST)     ← NOVO (fonte de verdade de versão)
    ↓
oasdiff breaking check                 ← NOVO (gate de breaking change)
    ↓
POST spec → Apicurio Registry          ← NOVO (armazenamento versionado)
    ↓
POST catalog/locations → Backstage     ← existente (EXP-006)
    ↓
Kong request-validator update          ← NOVO (enforçamento runtime)
```

**Novo componente na stack:** Apicurio Registry (Apache 2.0, self-hosted via Docker).

---

## Roadmap de Implementação

| Capability | Ferramenta | Horizon | EXP |
|---|---|---|---|
| Spectral lint no spire-submit.sh | Spectral CLI | Próximo | EXP-008 |
| Breaking change detection | oasdiff | Próximo | EXP-008 |
| Apicurio Registry na stack local | Docker service | Próximo | EXP-008 |
| OBC versioning (version + changelog no frontmatter) | Convenção | Imediato | qualquer |
| Kong request-validator por serviço | Kong plugin | EXP-008 | EXP-008 |
| Apicurio Backstage plugin | npm + config | EXP-008 | EXP-008 |
| Prism sidecar para dev | Docker | EXP-008 | EXP-008 |
| Pact Broker | Docker | Backlog | EXP-009+ |
| Microcks (AsyncAPI) | Docker/k8s | Backlog | quando event-driven |

---

## Referências

- [overview.md](overview.md) — arquitetura atual (pré Apicurio)
- [diagram.md](diagram.md) — diagramas de componente e sequência
- [EXP-007](../experiments/007-product-capabilities/experiment.md) — candidatos de capacidade
- [ADR-002](overview.md#adr-002) — static token bridging
- [ADR-005](overview.md#adr-005) — OBC como primitivo
