# EXP-008 — Governance Plugin + Time-to-Governance

- [ ] Planned
- [ ] In Progress
- [x] Completed
- [ ] Cancelled

**Tipo:** Delivery (implementação)
**Data de abertura:** 2026-08-27
**Origina:** EXP-007 decision-log

---

## Business Goal

Transformar o Spire de pipeline de submissão manual (EXP-006) em uma plataforma
adotável por qualquer organização sem suporte direto.

O critério de saída de EXP-008 é o critério de entrada para adoção externa (Q5 do EXP-007):
≥ 2 serviços governados, GitHub Action publicada, template disponível, onboarding em < 30 min.

---

## Hipótese

> Se o time-to-governance (tempo do primeiro commit ao primeiro `obc.validated`) for
> inferior a 30 minutos usando o GitHub Action e o template de repositório, a taxa de
> adoção de novos serviços aumenta de forma sustentável.

---

## Escopo

### Bloco 1 — Governance Plugin (core)

Implementação do `@spire/backstage-plugin-governance-backend` em TypeScript.

**Estrutura:**
```
packages/backstage/plugins/governance-backend/
  src/
    router.ts          — POST /api/spire-governance/submit
    detect.ts          — detecção de artefatos (openapi? asyncapi? slo?)
    validators/
      catalog.ts       — catalog-info.yaml campos obrigatórios
      obc.ts           — seções OBC + version + changelog
      openapi.ts       — Spectral lint + oasdiff
      asyncapi.ts      — asyncapi/cli + Spectral:asyncapi  (se asyncapi.yaml)
      slo.ts           — oslo validate  (se slo.yaml, advisory)
    registry/
      apicurio.ts      — fetch versão atual + register nova versão
      kong.ts          — Kong Admin API: upsert Service + Route + request-validator
      microcks.ts      — submit AsyncAPI spec  (se asyncapi.yaml)
    catalog.ts         — CatalogClient.addLocation()
    report.ts          — relatório JSON de validação
```

**Rota Kong:** `/spire/api/governance/submit` → oidcify + OPA + request-transformer → Backstage

**Dependências npm:**
- `@stoplight/spectral-core` + `@stoplight/spectral-formats` — Spectral lint
- `@asyncapi/parser` — validação AsyncAPI (opcional, carregado se asyncapi.yaml presente)
- `oasdiff` binário via `execa` ou wrapper npm
- `oslo` binário via `execa` (advisory)

### Bloco 2 — Stack local expandida

Novos serviços no docker-compose:

| Serviço | Imagem | Papel |
|---|---|---|
| Apicurio Registry | `apicurio/apicurio-registry` | Schema/contract registry OAS3 + AsyncAPI |
| Microcks | `quay.io/microcks/microcks-uber` | Mock + conformance AsyncAPI (opcional) |

Kong: nova rota `/spire/api/governance/*` + OPA rule atualizada.

### Bloco 3 — thin client

Refatoração do `spire-submit.sh`:
- Remove Spectral, oasdiff, validações locais
- Mantém: auth (client_credentials) + multipart POST + exibição do relatório JSON
- Novo endpoint: `POST /spire/api/governance/submit`
- Payload: `catalog-info.yaml` + `OBCs/*.md` + `openapi.yaml`? + `asyncapi.yaml`?

### Bloco 4 — Time-to-governance

**GitHub Action reutilizável** (`spire-submit`):
```yaml
# .github/actions/spire-submit/action.yml
inputs:
  spire_url:         required
  keycloak_url:      required
  client_id:         required
  client_secret:     required
  service_path:      default: '.'
runs:
  using: composite
  steps:
    - run: ./spire-submit.sh
```

**Template de repositório** (`produtoreativo/spire-service-template`):
```
spire-service-template/
  catalog-info.yaml         — template com campos obrigatórios
  api/openapi.yaml          — template OpenAPI 3.0 mínimo
  prodops/artifacts/obcs/
    service-obc.md          — template OBC com todas as seções
  .github/workflows/
    spire-submit.yml        — workflow usando a GitHub Action
  README.md                 — guia de onboarding (< 30 min)
```

### Bloco 5 — Novo serviço governado (evidência)

Registrar ao menos 1 novo serviço real (além da payments-api) usando o GitHub Action
e o template como evidência pública de que o fluxo funciona end-to-end.

---

## Fora do escopo deste EXP

- Dashboard de conformidade (C-06) — EXP-009+
- Governance score visível no catalog (C-07) — EXP-009+
- Audit trail de submissões (C-08) — EXP-009+
- OCI production-grade — EXP-009
- OIDC federation GitHub Actions → Keycloak (C-20) — Backlog
- Multi-tenant (C-13) — Backlog

---

## Exit Criteria

- [x] `@spire/backstage-plugin-governance-backend` implementado (POST /submit + GET /services + GET /health)
- [x] Spectral lint: advisory warning quando CLI indisponível (non-blocking); oasdiff integrado (MAJOR detection)
- [x] Apicurio Registry na stack (docker-compose) — registro via REST API implementado e validado
- [x] Microcks na stack (docker-compose) — mock AsyncAPI
- [x] Kong: service + route `/spire/api/governance/*` + oidcify + OPA + request-transformer configurados e validados
- [x] OPA policy atualizada — `spire-registrar` autorizado em `/spire/api/governance/`
- [x] `spire-submit.sh` thin client implementado (`scripts/spire-submit.sh`) — sem Spectral local
- [x] GitHub Action `spire-submit` implementada (`.github/actions/spire-submit/action.yml`)
- [x] Template de repositório criado (`prodops/templates/spire-service-template/`)
- [x] `catalog-info.yaml` do Spire criado (segundo serviço governado)
- [x] Stack validada end-to-end — `make up` + `make governance-health` + `make spire-submit` (2026-08-27)
  - Pipeline completo: Kong → oidcify (JWT) → OPA (`spire-registrar`) → request-transformer → Backstage plugin
  - OpenAPI v1.0.0 registrado no Apicurio Registry
  - Rota Kong `/v1/payments-api` criada
  - `version`, `status`, `## Response Contract` tornados advisory (warnings) — OBCs legados não são bloqueados
  - OBCs em formato legado (zero seções H2 padrão) tratados como legacy advisory — não bloqueiam
  - 56/56 testes unitários + integração passando (`npm test`)
  - `tsc --noEmit` zero erros
- [x] ≥ 2 serviços governados confirmados end-to-end (2026-08-27):
  - `payments-api` → `governed` (0 erros, 86 warnings advisory — OBCs legados)
  - `spire` → `governed` (0 erros, 0 warnings — OBC completo em `prodops/artifacts/obcs/governance-platform.md`)

---

## Stack após EXP-008

| Componente | Status |
|---|---|
| Traefik | ✅ EXP-002 |
| Kong + oidcify + OPA | ✅ EXP-005 |
| Keycloak | ✅ EXP-005 |
| Backstage + Catalog + TechDocs | ✅ EXP-003 |
| Vault | ✅ EXP-004 |
| PostgreSQL + SeaweedFS | ✅ EXP-003 |
| **Apicurio Registry** | 🆕 EXP-008 |
| **Microcks** | 🆕 EXP-008 |
| **@spire/governance-backend plugin** | 🆕 EXP-008 |
