# EXP-007 — Mapa de Capacidades do Spire

**Status:** Upstream. Concluído — decisões registradas em `decision-log.md`.
**Tipo:** Product Discovery
**Data de abertura:** 2026-08-26

---

## Contexto

Com o Product Deck inicial formalizado (visão, personas, OBC global, service model) e a
payments-api validando o ciclo completo de submissão (EXP-006), temos evidência suficiente
para discutir quais capacidades o Spire deve entregar — e em que ordem.

O risco sem essa discussão é entregar capacidades técnicas incrementais (EXP-007: GitHub
Action, EXP-008: OCI) sem um mapa de produto claro. Capacidades isoladas não geram
plataforma.

**Base de referência:**
- Personas definidas: Engenheiro de Plataforma + Tech Lead
- Métrica de produto: serviços registrados com OBC válido
- Stack validada: Backstage + Kong + Keycloak + OPA + Vault
- Referência de implementação: payments-api (EXP-006)

---

## Hipótese

> As capacidades que mais reduzem o time-to-governance (tempo do primeiro commit até o
> primeiro `obc.validated`) são as que mais aumentam a taxa de adoção — e portanto a
> métrica central de produto.

O que queremos validar nesta discussão:
1. Quais capacidades reduzem time-to-governance?
2. Quais capacidades criam lock-in positivo (difíceis de replicar fora do Spire)?
3. Quais são pre-requisitos técnicos vs diferenciais de produto?

---

## Mapa de Candidatos

### Área 1 — Submissão e Onboarding

Capacidades que reduzem o esforço do tech lead para registrar um serviço.

| ID | Capacidade | Quem beneficia | Impacto no time-to-governance |
|---|---|---|---|
| C-01 | `spire-submit.sh` genérico (entregue no EXP-006) | Tech Lead | Alto — linha de base |
| C-02 | GitHub Action reutilizável (`.github/actions/spire-submit`) | Tech Lead | Alto — zero configuração por repo |
| C-03 | Template de repositório com estrutura ProdOps pré-configurada | Tech Lead | Alto — scaffold completo |
| C-04 | Validação de OBC server-side (Spire rejeita OBC inválido antes de registrar) | Eng. Plataforma | Médio — auditabilidade |
| C-05 | Feedback de validação em PR (comment automático com erros de OBC) | Tech Lead | Alto — shift-left |

### Área 2 — Visibilidade e Observabilidade

Capacidades que respondem "qual é o estado de governança da organização hoje".

| ID | Capacidade | Quem beneficia | Impacto na métrica central |
|---|---|---|---|
| C-06 | Dashboard de conformidade: % serviços com OBC válido | Eng. Plataforma | Alto — torna a métrica visível |
| C-07 | Governance score por serviço (governed / partial / registered) | Ambos | Médio — priorização |
| C-08 | Histórico de submissões por serviço (audit trail) | Eng. Plataforma | Médio — rastreabilidade |
| C-09 | Alerta quando OBC de um serviço ativo fica sem `obc.validated` por X dias | Eng. Plataforma | Baixo agora, alto em escala |

### Área 3 — Governança de Plataforma

Capacidades que o Engenheiro de Plataforma usa para definir e enforçar política.

| ID | Capacidade | Quem beneficia | Diferencial vs concorrentes |
|---|---|---|---|
| C-10 | Policy de OBC obrigatório por tipo de serviço (ex: serviços `type: service` devem ter OBC) | Eng. Plataforma | Alto — controle estruturado |
| C-11 | Gate de CI bloqueante: pipeline falha se OBC inválido | Eng. Plataforma | Médio — enforçamento |
| C-12 | Role-based submission: só `spire-registrar` pode registrar (entregue no EXP-005/006) | Eng. Plataforma | Linha de base |
| C-13 | Multi-tenant: organizações separadas na mesma instância Spire | Eng. Plataforma | Baixo agora |

### Área 4 — Documentação e Descoberta

Capacidades que tornam o Spire a fonte de verdade para outros times descobrirem serviços.

| ID | Capacidade | Quem beneficia | Dependência |
|---|---|---|---|
| C-14 | TechDocs: OBCs renderizados como documentação navegável no Backstage | Tech Lead + Consumidores | Backstage TechDocs plugin |
| C-15 | API Explorer: spec OpenAPI navegável por serviço no Backstage | Consumidores de API | Backstage API plugin |
| C-16 | Relacionamentos: mapa de dependência entre serviços | Eng. Plataforma | catalog-info `dependsOn` |
| C-17 | Search: busca por serviço, OBC keyword, ou tag | Ambos | Backstage Search plugin |

### Área 5 — Segredos e Pipeline

Capacidades que tornam o ciclo de CI/CD seguro e operável.

| ID | Capacidade | Quem beneficia | Pré-requisito |
|---|---|---|---|
| C-18 | Vault: secrets de pipeline sem credencial em CI (SPIRE_CLIENT_SECRET no Vault) | Tech Lead + Segurança | EXP-004 (Vault entregue) |
| C-19 | Rotation automática de `SPIRE_CLIENT_SECRET` via Vault dynamic secrets | Eng. Plataforma | Vault + Keycloak integration |
| C-20 | OIDC federation: CI autentica via OIDC (GitHub Actions → Keycloak), sem secret estático | Tech Lead | Keycloak OIDC provider config |

---

## Questões para Discussão

As questões abaixo precisam de decisão antes de comprometer os próximos EXPs.

### Q1 — Onde o Spire entrega mais valor agora? ✅ DECIDIDO

**Decisão: (a) Time-to-governance.**
Facilitar que mais serviços cheguem ao estado `governed` rapidamente — C-02 (GitHub Action), C-03 (template de repositório), C-05 (feedback em PR).
A métrica de produto (`serviços com OBC válido`) só cresce se registrar for fácil. Visibility e enforçamento sem adoção são dashboard vazio.

### Q2 — Validação de OBC: cliente ou servidor? ✅ DECIDIDO

**Decisão: (c) Backstage plugin customizado.**
Toda a lógica de governança (Spectral, oasdiff, oslo, Apicurio, Kong deck sync) roda no `@spire/backstage-plugin-governance-backend`. O cliente (`spire-submit.sh`) é thin client: autentica, envia artefatos, recebe relatório. Ver `ADR-009` em `overview.md`.

### Q3 — Qual é o formato mínimo de um Service Deck? ✅ DECIDIDO

**Decisão:** Formato mínimo = `catalog-info.yaml` + `prodops/artifacts/obcs/*.md`.
Specs de API são opcionais:
- `api/openapi.yaml` — se presente → valida, publica no Kong, versiona no Apicurio
- `api/asyncapi.yaml` — se presente → valida, publica no Microcks, versiona no Apicurio
- Um serviço pode ter nenhum, um, ou ambos os specs — sem impacto no nível `governed`

**Rationale:** O que governa um serviço é o OBC, não a interface técnica. Um serviço
sem API pública (worker, batch job) pode ser plenamente governado sem spec de API.

### Q4 — O Spire precisa de uma UI própria ou o Backstage é suficiente? ✅ DECIDIDO

**Decisão: (c) Backstage + plugins customizados.**
O Spire vive dentro do Backstage — não ao lado dele. Plugins de frontend (governance score, dashboard de conformidade, formulário de submissão guiada) reutilizam auth, catalog e TechDocs sem novo serviço. Consistente com `ADR-009`.

### Q5 — Qual é a definição de "pronto" para adoção externa? ✅ DECIDIDO

**Decisão: (b) Produto adotável.**

Critérios obrigatórios para EXP-009 (versão pública):
- `@spire/backstage-plugin-governance-backend` funcionando end-to-end
- `spire-submit.sh` thin client documentado e testado
- GitHub Action reutilizável (`spire-submit`) publicada
- Template de repositório ProdOps disponível
- ≥ 2 serviços registrados com OBC válido (payments-api + 1 novo)
- Guia de onboarding para tech leads (instalação em < 30 min)

---

## Exit Criteria

- [x] Q1–Q5 respondidas com decisão explícita
- [x] Lista de capacidades priorizadas para EXP-008
- [x] Lista de capacidades descartadas (fora do escopo v1)
- [x] Critério de "pronto para adoção externa" definido

## Capacidades EXP-008 (priorizadas)

| ID | Capacidade | Prioridade |
|---|---|---|
| C-02 | GitHub Action reutilizável | Alta |
| C-03 | Template de repositório ProdOps | Alta |
| C-04 | Validação OBC server-side (Governance Plugin) | Alta — core |
| C-05 | Feedback em PR (comment automático) | Alta |
| C-14 | TechDocs: OBCs navegáveis no Backstage | Alta |
| C-15 | API Explorer: OpenAPI navegável no Backstage | Alta |
| C-18 | Vault: secrets de pipeline sem credencial em CI | Alta |

## Capacidades fora do escopo v1

| ID | Capacidade | Motivo |
|---|---|---|
| C-06 | Dashboard de conformidade | EXP-009+ — precisa de adoção primeiro |
| C-07 | Governance score | EXP-009+ |
| C-08 | Audit trail de submissões | EXP-009+ |
| C-09 | Alerta por inatividade de OBC | Escala — backlog |
| C-10 | Policy de OBC obrigatório por tipo | Enforçamento — pós adoção |
| C-11 | Gate de CI bloqueante | Enforçamento — pós adoção |
| C-13 | Multi-tenant | Backlog |
| C-19 | Rotation automática de secrets | Backlog |
| C-20 | OIDC federation GitHub Actions | Backlog |

## Artefatos Produzidos

- [x] `decision-log.md` — decisões e justificativas
- [x] `EXP-008` aberto com escopo, hipótese e exit criteria
- [x] `roadmap.md` atualizado
