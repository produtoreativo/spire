# Spire — Arquitetura da Plataforma

**Status:** Em evolução — atualizado a cada EXP concluído.
**Última atualização:** 2026-08-26 (pós análise de validação e versionamento de APIs)

---

→ Diagramas Mermaid: [diagram.md](diagram.md)

## Visão Geral dos Componentes

```
┌───────────────────────────────────────────────────────────────────┐
│  Cliente / CI Pipeline  (thin client — sem lógica de governança)  │
│                                                                   │
│  spire-submit.sh ──── GitHub Action (EXP-008)                    │
│  auth + multipart POST + exibição de relatório                   │
└───────────────────────────┬───────────────────────────────────────┘
                            │ POST /spire/api/governance/submit
                            │ multipart: catalog-info + openapi + OBCs
                            ▼
┌───────────────────────────────────────────────────────────────────┐
│  Traefik (Edge) — Reverse proxy + TLS                            │
└───────────────────────────┬───────────────────────────────────────┘
                            ▼
┌───────────────────────────────────────────────────────────────────┐
│  Kong API Gateway                                                 │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────────────────┐  │
│  │ oidcify  │  │ kong-opafy │  │ request-validator (runtime)  │  │
│  │ JWT val. │  │ OPA authz  │  │ schema atualizado p/ Registrar│  │
│  └──────────┘  └─────┬──────┘  └──────────────────────────────┘  │
└───────────────────────┼───────────────────────────────────────────┘
        authz ◄─────────┤
        ▼               │ allow=true + Bearer static-token
┌──────────────┐        ▼
│  OPA         │  ┌─────────────────────────────────────────────────┐
│  authz.rego  │  │  Backstage                                      │
└──────────────┘  │  ┌───────────────────────────────────────────┐  │
                  │  │  @spire/backstage-plugin-governance-backend│  │
┌──────────────┐  │  │                                           │  │
│  Keycloak    │  │  │  1. Spectral lint (spire-ruleset.yaml)    │  │
│  Identity    │  │  │  2. Fetch versão atual ──────────────┐    │  │
│  realm:spire │  │  │  3. oasdiff breaking check           │    │  │
└──────────────┘  │  │  4. Registra nova versão ◄───────────┘    │  │
                  │  │  5. CatalogClient.addLocation() ───────┐  │  │
                  │  │  6. Kong Admin API: request-validator ─┐│  │  │
                  │  │  7. Relatório JSON ao cliente          ││  │  │
                  │  └───────────────────────────────────────┼┼──┘  │
                  │  Catalog + TechDocs ◄───────────────────-┘│     │
                  └─────────────────────────────────────┬──────┘     │
                                                        │            │
                              ┌─────────────────────────┘            │
                              ▼                                      │
              ┌───────────────────────────┐                          │
              │  Apicurio Registry        │◄─────────────────────────┘
              │  OAS3 · AsyncAPI          │  (Backstage plugin renderiza
              │  Versioning + Compat.     │   versões no Catalog)
              └───────────────────────────┘
                              │ Backstage plugin
                              ▼
              ┌───────────────────────────┐
              │  Backstage Catalog        │
              │  API Explorer + TechDocs  │
              └──────────┬───────────────-┘
                         │
            ┌────────────┴─────────┐
            │  PostgreSQL          │  ┌─────────────────┐
            └──────────────────────┘  │  SeaweedFS      │
                                      │  TechDocs assets│
  ┌────────────┐  ┌──────────────────┐└─────────────────┘
  │  Vault     │  │  Prism (dev/stg) │
  │  Secrets   │  │  Mock + Response │
  └────────────┘  └──────────────────┘
```

---

## Stack de Infraestrutura

**Componentes de runtime (stack atual — EXP-006 validado):**

| Componente | Papel | Versão/Imagem | EXP |
|---|---|---|---|
| Traefik | Reverse proxy, TLS termination, roteamento por hostname | traefik:v3 | EXP-002 |
| Kong | API Gateway — autenticação, autorização, validação, transformação | kong:3.x | EXP-005 |
| Keycloak | Identity Provider — OIDC, client_credentials, realm `spire` | keycloak:24 | EXP-005 |
| OPA | Policy engine — decisões de autorização (allow/deny) | openpolicyagent/opa | EXP-005 |
| Backstage | Catalog, TechDocs, API Explorer | backstage:latest | EXP-003 |
| Vault | Gestão de segredos — AppRole, OIDC, dynamic secrets | vault:1.15 | EXP-004 |
| PostgreSQL | Banco de dados do Backstage catalog | postgres:15 | EXP-003 |
| SeaweedFS | Object storage para assets do TechDocs | chrislusf/seaweedfs | EXP-003 |

**Componentes de validação e versionamento (planejado — EXP-008):**

| Componente | Papel | Licença | Tipo |
|---|---|---|---|
| Spectral | Lint de OpenAPI/AsyncAPI com rulesets customizáveis | Apache 2.0 | CLI |
| oasdiff | Detecção de breaking changes entre versões de OpenAPI | Apache 2.0 | CLI/Docker |
| Apicurio Registry | Schema/contract registry — armazena e versiona OAS3, AsyncAPI | Apache 2.0 | Servidor |
| Kong request-validator | Validação de requests em runtime contra JSON Schema | Kong (free) | Plugin Kong |
| Prism | Mock server + proxy de validação de responses (dev/staging) | Apache 2.0 | Docker sidecar |

**Componentes futuros (backlog):**

| Componente | Papel | Quando |
|---|---|---|
| Pact Broker | Consumer-driven contract tests entre serviços | ≥ 2 serviços integrados |
| Microcks | Mocking + contract testing para AsyncAPI/eventos | Serviços event-driven |

---

## Fluxo de Autenticação e Autorização

### Pipeline de submissão (spire-submit.sh)

```
[CLIENTE — thin client, sem lógica de governança]

1. Script autentica via Keycloak (client_credentials)
   POST /realms/spire/protocol/openid-connect/token
   → client_id: <service>-pipeline
   → client_secret: <do Vault ou CI secret>
   ← JWT { aud: ["kong"], realm_access: { roles: ["spire-registrar"] } }

2. Script envia artefatos ao Spire (multipart)
   POST /spire/api/governance/submit
   Authorization: Bearer <JWT>
   Body: catalog-info.yaml + openapi.yaml + OBCs

   O cliente não sabe nada sobre Spectral, oasdiff ou Apicurio.
   Ele entrega os artefatos e recebe um relatório.

[KONG — auth + authz, como para qualquer rota]

3. Kong — oidcify plugin
   → valida JWT contra Keycloak JWKS
   → REJEITA se multi-audience

4. Kong — kong-opafy plugin
   → OPA avalia: role "spire-registrar" + path "/spire/api/governance/*"
   → allow = true → Kong encaminha ao Spire Registrar Service

[SPIRE REGISTRAR SERVICE — toda a governança acontece aqui]

5. Spectral lint
   → openapi.yaml validado contra spire-spectral-ruleset.yaml
   → erros críticos bloqueiam; warnings são reportados

6. Apicurio: busca versão atual
   GET /groups/spire/artifacts/{artifactId}/versions/latest
   → referência para o diff de breaking change

7. oasdiff: breaking change detection
   → breaking → exige MAJOR version bump (1.x → 2.0.0)
   → non-breaking → MINOR ou PATCH

8. Apicurio: registra nova versão
   POST /groups/spire/artifacts/{artifactId}/versions
   → fonte de verdade versionada; Backstage plugin renderiza no catalog

9. Backstage: registra location do serviço
   POST /api/catalog/locations
   → HTTP 201 (novo) | 409 (idempotente — refresh agendado)

10. Kong: deck sync — atualiza request-validator
    → JSON Schema extraído do openapi.yaml injetado na rota do serviço
    → requests inválidos retornam HTTP 400 em runtime
    → fecha o loop: spec declarada = spec enforçada em produção

11. Relatório retornado ao cliente
    { status, version_registered, errors, warnings, catalog_url }

[RUNTIME — Kong valida requests de usuários finais]

12. Kong — request-validator plugin (por rota de serviço)
    → schema atualizado pelo Registrar no step 10
    → transparente para o cliente e para o serviço backend
```

### Usuário humano (browser / Backstage UI)

```
Usuário → Traefik → Kong → Backstage
(autenticação via Keycloak OIDC — authorization_code flow)
OPA: regras por role de usuário (não spire-registrar)
```

---

## Decisões de Arquitetura

### ADR-001 — OPA como engine de autorização (não RBAC nativo do Kong)

**Decisão:** Usar OPA via `kong-opafy` em vez do plugin ACL nativo do Kong.

**Contexto:** O RBAC nativo do Kong é simples mas não permite lógica composta (path + method + role). OPA permite políticas declarativas em Rego, testáveis em CI e auditáveis.

**Consequências:** Latência adicional por request (< 5ms local). Policy centralizada em `authz.rego` — mudança de regra não requer redeploy do Kong.

---

### ADR-002 — Static token bridging (Kong → Backstage)

**Decisão:** Kong injeta um token estático (`BACKSTAGE_PIPELINE_TOKEN`) no header após OPA aprovar, em vez de repassar o JWT Keycloak ao Backstage.

**Contexto:** Backstage tem seu próprio sistema de autenticação (`backend.auth.externalAccess`) e não consome JWTs Keycloak diretamente sem plugin adicional. O bridging via `request-transformer` isola a autenticação do Keycloak da autenticação do Backstage.

**Consequências:** Backstage não precisa saber sobre Keycloak. Pipeline de autenticação: JWT Keycloak (para Kong/OPA) + Static token (para Backstage). Token estático rotacionado via variável de ambiente; em produção, gerenciado pelo Vault.

---

### ADR-003 — Keycloak service account: remover `default-roles-spire`

**Decisão:** Service accounts de pipeline NÃO devem ter o composite role `default-roles-spire`.

**Contexto:** `default-roles-spire` inclui roles do client `account` (manage-account, view-profile), o que adiciona `account` ao campo `aud` do JWT. O plugin `oidcify` rejeita tokens com múltiplos audiences (`"token does not contain exactly one audience"`).

**Fix aplicado:** DELETE `default-roles-spire` do service account via Keycloak Admin API após criação do client.

**Consequências:** Token de pipeline fica com `aud: ["kong"]` apenas. `fullScopeAllowed: false` não é suficiente (zeros `realm_access.roles`); a remoção da role é o approach correto.

---

### ADR-004 — Backstage como backbone do catalog (não construído do zero)

**Decisão:** Usar Backstage como catalog engine — não construir um catalog proprietário.

**Contexto:** Backstage tem catalog, TechDocs, API Explorer, search e plugin ecosystem maduros. Spire adiciona governança (OBC, pipeline de submissão, OPA) sobre o Backstage, não substitui o catalog.

**Consequências:** Spire depende do Backstage como runtime de catalog. Customizações são feitas via plugins e configuração (`app-config.local.yaml`), não no código do Backstage.

---

### ADR-005 — OBC como primitivo de governança (não annotation do Backstage)

**Decisão:** OBC é um arquivo Markdown estruturado no repositório do serviço (`prodops/artifacts/obcs/*.md`), validado pelo `spire-submit.sh` antes do registro.

**Contexto:** Backstage annotations são metadata auto-declarada sem validação de schema ou conteúdo. OBC como arquivo do repositório: versionado em git, validável em CI, legível por humanos e máquinas.

**Consequências:** OBC não é um campo do `catalog-info.yaml` — é um artefato de primeira classe. A validação acontece client-side (hoje, no script) com evolução planejada para server-side (EXP-008+).

---

### ADR-006 — Apicurio Registry como fonte de verdade para versões de spec

**Decisão:** Apicurio Registry (open-source, Apache 2.0) é o componente de armazenamento e versionamento de specs OpenAPI e AsyncAPI — não o repositório Git nem o Backstage catalog.

**Contexto:** Git tem a spec do momento atual, mas não tem versionamento semântico, regras de compatibilidade (backward/forward/full) nem API de consulta para ferramentas de diff. Backstage catalog tem a spec como referência de documentação, mas não como registry com lifecycle de versão. O Apicurio serve ambos: armazena versões com semver, expõe REST API para `oasdiff` consultar, e tem plugin nativo do Backstage.

**Consequências:** O fluxo de submissão ganha dois passos: buscar versão atual do Apicurio (para diff) e registrar nova versão antes de submeter ao Backstage. Apicurio entra na stack local como novo container no docker-compose (EXP-008). Em produção, Apicurio requer PostgreSQL próprio ou pode compartilhar a instância existente.

---

### ADR-007 — Versionamento semântico de APIs e OBCs

**Decisão:** APIs (OpenAPI/AsyncAPI) seguem semver com breaking change detection automático via `oasdiff`. OBCs seguem semver manual com campo `version` e seção `changelog` no frontmatter Markdown.

**Regra para APIs:**
```
MAJOR → oasdiff detecta breaking change → gate bloqueia sem bump explícito
MINOR → oasdiff detecta non-breaking addition → autor decide
PATCH → sem diff comportamental → patch automático pelo script
```

**Regra para OBCs:**
```
MAJOR → Observable Event renomeado/removido ou Response Contract breaking
         → exige novo Business Intent (mudança de contrato de negócio = nova intenção)
MINOR → novo Observable Event ou novo SLI adicionado
PATCH → correção de texto, exemplo, descrição
```

**Consequências:** OBC MAJOR = Business Intent novo obrigatório. Isso é intencional — uma mudança breaking de contrato de negócio não é apenas técnica; presupõe decisão de produto.

---

### ADR-008 — Validação de requests em runtime via Kong request-validator

**Decisão:** O plugin `request-validator` do Kong (nativo, gratuito) valida requests contra JSON Schema extraído da spec OpenAPI no momento do deck sync — antes de chegar ao backend do serviço.

**Contexto:** Sem validação em runtime, um serviço pode ter spec válida no Spire mas aceitar payloads inválidos em produção. O Kong já está no critical path de todo request; adicionar o plugin não requer novo componente.

**Consequências:** A spec registrada no Apicurio passa a ser enforçada em runtime pelo Kong. O Spire fecha o loop entre governança (spec declarada) e operação (spec respeitada). Limitação: o plugin valida apenas requests, não responses — para response validation em dev/staging, usar Prism como proxy.

---

### ADR-009 — Spire Governance como Backstage backend plugin (não serviço externo)

**Decisão:** Toda a lógica de governança (Spectral lint, oasdiff, Apicurio, deck sync do Kong) é implementada como um **Backstage backend plugin** (`@spire/backstage-plugin-governance-backend`). O Spire Governance não é um serviço separado — é uma extensão do Backstage.

**Contexto:** O modelo anterior colocava Spectral, oasdiff e a integração com Apicurio na pipeline do serviço cliente, criando acoplamento indesejado. A alternativa natural seria um serviço externo, mas isso adicionaria um novo componente à stack com seu próprio ciclo de deploy, healthcheck e auth. O Backstage já possui uma arquitetura de backend plugins madura: plugins expõem rotas HTTP, têm acesso direto ao catalog client e ao banco de dados, e usam o mesmo modelo de auth (`externalAccess`) que já está configurado.

**Princípio:** O cliente entrega artefatos. O Spire (via plugin Backstage) governa.

**Implementação:**
```
packages/backend/src/plugins/spire-governance/
  ├── router.ts          — POST /api/spire-governance/submit
  ├── spectral.ts        — lint + spire-spectral-ruleset.yaml
  ├── oasdiff.ts         — breaking change detection
  ├── apicurio.ts        — fetch + register versão
  ├── kong-sync.ts       — Kong Admin API: atualiza request-validator
  └── catalog.ts         — POST catalog/locations via CatalogClient
```

Kong roteia `/spire/api/governance/*` → Backstage `/api/spire-governance/*` (mesma cadeia de auth: oidcify → OPA → request-transformer).

**Consequências:**
- Stack não ganha novo componente de runtime — apenas um novo plugin no Backstage existente
- `spire-submit.sh` vira thin client: auth + multipart POST + exibição de relatório
- Regras de validação ficam centralizadas no Spire — atualizações não exigem mudanças nos pipelines clientes
- Plugin tem acesso direto ao CatalogClient, sem HTTP round-trip para registrar entities
- Backstage upgrade exige compatibilidade do plugin — versão do plugin deve seguir API do Backstage backend framework

### ADR-010 — Kong como registro público de APIs versionadas (tags + lifecycle)

**Decisão:** Cada versão major de uma API governada pelo Spire gera uma entidade Kong distinta (`Service payments-api-v{N}` + `Route /v{N}/{slug}`), gerenciada pelo plugin via Kong Admin API com tags estruturadas (`spire`, `service:{name}`, `version:v{N}`, `active|deprecated|sunset`).

**Contexto:** Sem um modelo de organização explícito, o Kong acumula rotas sem rastreabilidade de versão — impossível saber quais pertencem ao Spire, quais estão deprecated, ou deletar uma versão com segurança. Tags estruturadas permitem consultas, lifecycle management e automação sem ambiguidade.

**Modelo de derivação automática:**
```
openapi.yaml info.title  → slug do serviço (kebab-case)
openapi.yaml info.version → major version (semver → v{N})
openapi.yaml servers[0].url → upstream URL do Service
openapi.yaml paths.*.requestBody.schema → body_schema do request-validator
```

**Lifecycle por tipo de change:**
- PATCH/MINOR → atualiza só `request-validator` schema na route existente
- MAJOR (breaking, detectado por oasdiff) → cria nova route `/v{N}/...` + marca versão anterior como `deprecated`
- Sunset explícito → adiciona `Deprecation` + `Sunset` headers via `response-transformer`
- Delete explícito → remove entidades Kong (apenas versões `deprecated`)

**Consequências:** O plugin precisa de acesso à Kong Admin API (configurado como secret interno — não exposto ao cliente). Versões antigas nunca são deletadas automaticamente — deleção é sempre explícita. O Backstage catalog reflete o estado do Kong via annotations `spire.io/api-status`.

→ Detalhe completo: [kong-api-publication.md](kong-api-publication.md)

---

## Configuração Crítica por Componente

### Backstage (`app-config.local.yaml`)

```yaml
backend:
  auth:
    externalAccess:
      - type: static
        options:
          token: ${BACKSTAGE_PIPELINE_TOKEN}
          subject: spire-pipeline    # identidade do pipeline no Backstage

integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN:-github-token-not-configured}
      # token vazio string quebra o Backstage — usar placeholder
```

### Kong (kong.yml)

```yaml
# Rota do Backstage (registro de catalog)
- name: backstage-api-route
  paths: ["/backstage"]
  plugins:
    - name: oidcify              # valida JWT Keycloak
    - name: kong-opafy           # consulta OPA
    - name: request-transformer  # injeta BACKSTAGE_PIPELINE_TOKEN

# Rota de serviço governado (exemplo: payments-api)
# gerado pelo spire-submit.sh a partir da spec OpenAPI
- name: payments-api-route
  paths: ["/payments"]
  plugins:
    - name: oidcify
    - name: kong-opafy
    - name: request-validator    # schema extraído do openapi.yaml no deck sync
      config:
        body_schema: '{"type":"object","required":["amount"],...}'
        allowed_content_types: ["application/json"]
```

### OPA (`authz.rego` — regra de pipeline)

```rego
allow if {
    "spire-registrar" in roles
    startswith(input.path, "/backstage/api/catalog/")
    input.method in {"GET", "POST"}
}
```

### Keycloak (client `payments-api-pipeline`)

```json
{
  "clientId": "payments-api-pipeline",
  "serviceAccountsEnabled": true,
  "standardFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "protocolMappers": [
    { "name": "audience-kong", "config": { "included.client.audience": "kong" } }
  ]
}
```

---

## Capacidades Planejadas (pós EXP-006)

Ver [EXP-007](../experiments/007-product-capabilities/experiment.md) — mapa de candidatos
e questões de decisão em aberto.
Ver [api-validation-strategy.md](api-validation-strategy.md) — estratégia de validação e versionamento.

| Capacidade | Componente impactado | EXP alvo |
|---|---|---|
**Spire Registrar Service (novo componente — coração do EXP-008):**

| Capacidade | Componente | EXP alvo |
|---|---|---|
| Spire Registrar Service (backend de governança) | Novo serviço (FastAPI ou Node.js) | EXP-008 |
| Spectral lint server-side (no Registrar) | Spectral CLI embutido | EXP-008 |
| oasdiff breaking change (no Registrar) | oasdiff binário embutido | EXP-008 |
| Apicurio Registry na stack + integração Registrar | docker-compose + REST API | EXP-008 |
| Kong deck sync: request-validator por serviço | Kong Admin API (Registrar chama) | EXP-008 |
| OBC versioning (version + changelog no frontmatter) | Convenção + validação no Registrar | EXP-008 |
| spire-submit.sh refatorado como thin client | CLI / multipart POST | EXP-008 |

**Pipeline e infraestrutura:**

| Capacidade | Componente | EXP alvo |
|---|---|---|
| GitHub Action para submissão automática | CI / spire-submit.sh | EXP-008 |
| Vault para segredo de pipeline (SPIRE_CLIENT_SECRET) | Vault + CI | EXP-008 |
| TechDocs: OBCs como documentação navegável | Backstage TechDocs | EXP-008 |
| Apicurio Backstage plugin | npm + config | EXP-008 |
| Prism como sidecar de dev | docker-compose (dev profile) | EXP-008 |
| OCI production-grade | Terraform + Oracle Cloud | EXP-009 |

**Backlog:**

| Capacidade | Componente | Quando |
|---|---|---|
| Dashboard de conformidade | Backstage plugin custom | Backlog |
| Pact Broker (consumer contracts) | Docker + Backstage plugin | ≥ 2 serviços integrados |
| Microcks (AsyncAPI mocking) | Docker/k8s | Serviços event-driven |
| OIDC federation para pipelines | Keycloak + GitHub OIDC | Backlog |
