# EXP-006 — payments-api: Primeiro Serviço Governado pelo Spire

- [ ] Planned
- [ ] In Progress
- [x] Completed
- [ ] Cancelled

---

# Business Goal

Validar o Spire como plataforma de governança de serviços usando a payments-api como
prova de conceito. A payments-api **não sabe que o Spire existe** — ela opera normalmente
no próprio ecossistema (AWS Lambda, staging). O Spire recebe seus artefatos via pipeline
e os cataloga, valida e publica.

O resultado é o padrão de integração que qualquer serviço pode adotar para ser governado
pelo Spire: uma pipeline de submissão que envia `catalog-info.yaml`, spec OpenAPI e OBCs
ao Spire — e o Spire retorna um relatório de validação e publica o serviço em seu catalog.

**O Spire não é proxy, não é gateway para a payments-api.** É a plataforma que
registra, valida e exibe o serviço como governado.

---

# Repository Scope Gate

- [x] Testes locais ou evidência executável
- [x] Integração com dois repositórios (spire + payments-api)
- [x] Comportamento de plataforma (Backstage catalog, Spire API, validação de OBCs)

**Decisão de escopo:** Upstream executável que prova o padrão de governança.
Artefatos de plataforma vivem em `spire/`. Artefatos de submissão vivem em `payments-api/`.

---

# Questions to Answer

| Q | Pergunta | Resposta |
|---|---|---|
| Q1 | Backstage consegue registrar a payments-api via `catalog-info.yaml` lido do GitHub? | **Sim** — POST /backstage/api/catalog/locations registra a URL e Backstage busca via GitHub integration |
| Q2 | O Spire consegue validar que os OBCs da payments-api têm as seções obrigatórias? | **Sim** — `spire-submit.sh` valida localmente antes de submeter (28/30 OBCs válidos) |
| Q3 | Uma pipeline consegue submeter artefatos ao Spire de forma autenticada? | **Sim** — client_credentials via `payments-api-pipeline` → Kong → OPA (allow=True) → Backstage |
| Q4 | A OpenAPI spec da payments-api pode ser gerada e consumida pelo Backstage? | **Sim** — `api/openapi.yaml` criado manualmente, referenciado no `catalog-info.yaml` via `$text` |
| Q5 | O padrão de submissão é replicável para outros serviços? | **Sim** — `spire-submit.sh` é genérico; auto-descobre artefatos, valida e submete |

---

# Hypothesis

**Confirmada.** É possível usar o Spire como plataforma de governança sem modificar
nenhum código da payments-api: a pipeline de submissão é uma adição ao CI/CD que
envia artefatos já existentes (OBCs, catalog-info, spec) ao Spire para validação
e publicação.

---

# Scope

## Protocolo de Submissão (implementado)

```
pipeline (payments-api CI/CD)
  │
  │  POST /backstage/api/catalog/locations
  │  Authorization: Bearer <Keycloak JWT — spire-registrar role>
  │  Body: {"type": "url", "target": "<GitHub raw URL de catalog-info.yaml>"}
  │
  ▼
Kong (oidcify → OPA: spire-registrar allow=True)
  │  request-transformer: substitui Authorization header pelo Backstage static token
  │
  ▼
Backstage catalog API
  │  → registra location (GitHub raw URL)
  │  → agenda fetch do catalog-info.yaml via GitHub integration
  │  → retorna 201 (location criada) ou 409 (já existe — refresh)
  │
  ▼
Backstage catalog (entidade payments-api visível)
```

## Validação local (spire-submit.sh)

O script valida antes de submeter:
- `catalog-info.yaml`: campos obrigatórios (name, type, owner, lifecycle, system=spire)
- `api/openapi.yaml`: versão 3.x, info.title, info.version, paths não vazio
- `prodops/artifacts/obcs/*.md`: seções ## Business Outcome e ## Observable Events

## Artefatos criados

| Artefato | Repo | Status |
|---|---|---|
| `catalog-info.yaml` | payments-api | ✅ Criado — Component + API entity |
| `api/openapi.yaml` | payments-api | ✅ Criado — OpenAPI 3.0.3, 8 paths |
| `scripts/spire-submit.sh` | payments-api | ✅ Criado — genérico e reusável |
| `iac/environments/local/opa/policies/authz.rego` | spire | ✅ Regra spire-registrar adicionada |
| `iac/environments/local/vault/policies/pipeline-payments-api.hcl` | spire | ✅ Criado |
| `iac/environments/local/keycloak/realm-spire.json` | spire | ✅ Client + role adicionados |
| `iac/environments/local/backstage/app-config.local.yaml` | spire | ✅ GitHub integration + externalAccess |
| `iac/environments/local/docker-compose.yml` | spire | ✅ BACKSTAGE_PIPELINE_TOKEN + GITHUB_TOKEN |

---

# Technical Findings

## 1. oidcify exige exatamente um `aud` no JWT

O token de service account de Keycloak vinha com `aud: ['kong', 'account']` — dois audiences.
O `account` vem do `default-roles-spire` composite role que inclui roles do client `account`
(manage-account, view-profile). Solução: remover `default-roles-spire` do service account
via Admin API — token passou a ter `aud: kong` (singular).

## 2. `fullScopeAllowed: false` zera realm_access.roles

Tentativa de reduzir o `aud` via `fullScopeAllowed: false` eliminou os roles do JWT mesmo
com o `roles` scope atribuído. O Keycloak filtra realm roles fora do scope quando
`fullScopeAllowed: false`. A solução correta foi remover o `default-roles-spire` do SA.

## 3. Backstage não aceita JWT Keycloak diretamente

`DefaultAuthService.authenticate()` valida apenas tokens internos do Backstage.
Para aceitar tokens externos, o config key correto é `backend.auth.externalAccess` (não `auth.externalAccess`).
Kong usa o plugin `request-transformer` para substituir o Bearer header
com o token estático Backstage após OPA aprovar.

## 4. `auth.externalAccess[0].options.token` requer env var não-vazia

`BACKSTAGE_PIPELINE_TOKEN` precisa estar no bloco `environment` do docker-compose.
Backstage trata string vazia como `Missing required config value` e não inicializa.

## 5. `integrations.github[0].token` não aceita string vazia

Se `GITHUB_TOKEN` não está configurado, usar `${GITHUB_TOKEN:-github-token-not-configured}` como
placeholder para evitar falha de startup. A integração fica configurada mas sem acesso real ao GitHub.

## 6. `sort -z` não funciona no macOS BSD sort

`find ... -print0 | sort -z` é GNU only. Substituído por `find ... | LC_ALL=C sort` no script.

## 7. `((var++))` com `set -e` falha quando `var=0`

`((0++))` avalia para 0 (falso) → `set -e` mata o script. Substituído por
`var=$((var + 1))` em todos os incrementos do `validate_obcs`.

## 8. `head -n -1` não funciona no macOS

GNU only. Substituído por `curl -o file -w "%{http_code}"` + `cat file`.

---

# Business Findings

1. **Tempo de integração**: Novo serviço pode ser governado pelo Spire em menos de 1 dia (catalog-info + openapi + script).
2. **Validação de OBCs**: 28 de 30 OBCs da payments-api passaram automaticamente. Os 2 warnings (boleto-auto-cancellation, chargeback-handling) refletem OBCs em formato legado.
3. **Zero impacto no serviço**: payments-api não foi modificada — apenas artefatos adicionados.
4. **Reusabilidade**: `spire-submit.sh` funciona com qualquer repositório que siga o layout padrão.

---

# Architecture Impact

```
[payments-api CI/CD]
  → scripts/spire-submit.sh
    → valida localmente (catalog, openapi, OBCs)
    → Keycloak client_credentials → JWT (aud=kong, roles=[spire-registrar])
    → Kong /backstage/api/catalog/locations
      → oidcify: valida JWT
      → OPA: spire-registrar can POST /backstage/api/catalog/* → allow=True
      → request-transformer: troca Bearer por Backstage static token
      → Backstage catalog API: registra GitHub URL como location
        → Backstage faz fetch via GitHub integration
        → payments-api visível como Component no catalog
```

**Componentes Spire adicionados:**
- Role Keycloak: `spire-registrar`
- Client Keycloak: `payments-api-pipeline` (serviceAccountsEnabled, client_credentials)
- OPA rule: `spire-registrar` pode GET+POST `/backstage/api/catalog/*`
- Kong plugin: `request-transformer` na rota backstage-api-route
- Backstage config: `backend.auth.externalAccess` com static token
- Backstage config: `integrations.github` para fetch de catalog-info.yaml

---

# Reliability Impact

- A submissão é idempotente: 201 (novo) ou 409 (já existe — Backstage refreshes)
- Se o GitHub integration não estiver configurado (GITHUB_TOKEN vazio), a location é
  registrada mas o Backstage não consegue buscar o catalog-info.yaml
- O static token no Backstage é um segredo — deve ser rotacionado periodicamente em produção

---

# Knowledge Gaps Closed

| Pergunta | Status | Evidência |
|---|---|---|
| Backstage consegue registrar via catalog-info.yaml do GitHub? | ✅ Sim | HTTP 201 no POST /backstage/api/catalog/locations |
| Pipeline autentica com client credentials + Kong? | ✅ Sim | JWT com aud=kong, roles=[spire-registrar] → OPA allow=True |
| OpenAPI spec da payments-api pode ser gerada e consumida? | ✅ Sim | api/openapi.yaml criado e referenciado no catalog-info.yaml |
| Padrão é replicável para outros serviços? | ✅ Sim | spire-submit.sh é genérico — nenhuma referência hardcoded |
| Backstage aceita tokens externos? | ✅ Sim | backend.auth.externalAccess com static token |

---

# New Backlog Items

| Item | Experimento |
|---|---|
| GitHub Action no repo payments-api para submissão automática ao Spire no push | EXP-007 |
| TechDocs automático: OBCs como documentação navegável no Backstage | EXP-007 |
| Backstage plugin de validação server-side (atualmente feita no script cliente) | EXP-007 |
| Vault integration: pipeline busca SPIRE_CLIENT_SECRET do Vault em vez de env var | EXP-007 |
| OCI — migração do stack local para Oracle Cloud | EXP-008 |

---

# Recommendation

**Adotar o padrão de submissão.** O EXP-006 prova que:
1. Qualquer serviço pode ser governado pelo Spire sem modificação no código do serviço
2. A validação de artefatos (OBCs, OpenAPI, catalog) é automatizável e executável em CI
3. O Backstage catalog é o registro central de governança

**Próximo passo recomendado (EXP-007):** Automatizar a submissão via GitHub Action
no repositório payments-api — submissão automática no push para `main`.

---

# Decision Package

**Padrão de Governança Spire v1.0:**

Um serviço é governado pelo Spire quando:
1. Tem `catalog-info.yaml` com `spec.system: spire` na raiz do repositório
2. Tem spec OpenAPI 3.x em `api/openapi.yaml`
3. Tem OBCs em `prodops/artifacts/obcs/*.md` com `## Business Outcome` e `## Observable Events`
4. Executa `scripts/spire-submit.sh` em sua pipeline com as credenciais `spire-registrar`

O Spire fornece:
- Keycloak client para autenticação da pipeline (client_credentials)
- Kong + OPA para autorização do endpoint de registro
- Backstage catalog como registro canônico de serviços governados

---

# Exit Criteria

- [x] Hipótese original respondida
- [x] Perguntas Q1–Q5 classificadas
- [x] payments-api visível no Backstage catalog após submissão manual (HTTP 201)
- [x] OBCs validados localmente pelo script (28/30 válidos)
- [x] Kong + OPA protegem o endpoint de registro (spire-registrar allow=True)
- [x] Script de submissão funciona ponta a ponta (client credentials → Kong → Backstage)
- [x] Padrão documentado como replicável para outros serviços
- [x] Impacto arquitetural documentado
- [x] Recomendação produzida
- [x] Decision Package completo
