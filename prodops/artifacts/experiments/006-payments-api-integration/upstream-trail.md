# EXP-006 — Upstream Trail (Payments API Integration)

Experimento: [experiment.md](experiment.md)

---

# History

## 2026-08-26 — Planejamento

### Activity

Experimento criado para integrar a payments-api ao Spire. Serviço identificado em
`produtoreativo/payments-api` — NestJS Lambda AWS com staging em us-east-1.

Análise do `.env` do repositório: staging URL, API token e admin secret disponíveis.
Mapeamento completo da superfície de API: `/health`, `/invoices`, `/split-payments`,
`/admin/tokens`, endpoints de webhook Asaas.

Padrão de integração definido: Spire como plataforma de governança (não proxy).
payments-api opera no próprio ecossistema; uma pipeline de submissão envia seus
artefatos (catalog-info, openapi, OBCs) ao Spire para validação e publicação.

### Contexto da decisão

EXP-005 validou o stack Kong + oidcify + kong-opafy + OPA. EXP-006 é o primeiro
uso real do Spire como plataforma: um serviço externo (payments-api) sendo governado
pelo Spire sem saber que ele existe — a submissão é feita por pipeline, não pela API.

A payments-api já tem >15 OBCs em `prodops/artifacts/obcs/`. O experimento valida
se o Backstage plugin Spire consegue receber, validar e publicar esses artefatos.

### Decision

Experimento aprovado. Prioridade máxima — valida o propósito central do Spire:
ser uma plataforma de governança de serviços, não apenas infraestrutura de API.

### Artifacts Updated

- `prodops/artifacts/experiments/006-payments-api-integration/experiment.md` (criado)
- `prodops/artifacts/experiments/006-payments-api-integration/upstream-trail.md` (criado)

---

## 2026-08-26 — Implementação e Conclusão

### Activity

Implementação completa do EXP-006. Escopo original previa plugin Backstage backend
customizado (POST /api/spire/register) — pivotado para usar a Backstage catalog API
nativa (POST /backstage/api/catalog/locations), eliminando a necessidade de um novo plugin.

**Findings técnicos relevantes:**

1. **oidcify exige aud singular** — service account Keycloak adicionava `account` como segundo
   audience via `default-roles-spire` composite role. Solução: remover `default-roles-spire`
   do service account `payments-api-pipeline`. Documentado em realm-spire.json como comportamento
   esperado para futuros clients de pipeline.

2. **Backstage backend.auth.externalAccess** — caminho de config correto é `backend.auth.externalAccess`
   (não `auth.externalAccess`). Kong usa `request-transformer` para substituir o Authorization header
   com o static token Backstage após OPA aprovar — solução elegante sem modificar o plugin oidcify.

3. **spire-submit.sh** — script genérico criado no repo payments-api. Portabilidade macOS
   resolvida: `sort -z` → `LC_ALL=C sort`, `head -n -1` → `curl -o file`, `((var++))` →
   `var=$((var + 1))` (compatibilidade com `set -e`).

4. **OBCs da payments-api**: 28/30 passaram validação. Dois OBCs legados
   (boleto-auto-cancellation, chargeback-handling) precisam de seções padrão.

### Decision

EXP-006 concluído. Hipótese confirmada. Padrão de governança documentado e
executável. Próximo: EXP-007 — GitHub Action para submissão automática.

### Artifacts Updated

**payments-api:**
- `catalog-info.yaml` (criado — Component + API entity)
- `api/openapi.yaml` (criado — OpenAPI 3.0.3, 8 paths)
- `scripts/spire-submit.sh` (criado — genérico, reusável)

**spire:**
- `iac/environments/local/opa/policies/authz.rego` (regra spire-registrar)
- `iac/environments/local/vault/policies/pipeline-payments-api.hcl` (criado)
- `iac/environments/local/keycloak/realm-spire.json` (client payments-api-pipeline + role spire-registrar)
- `iac/environments/local/backstage/app-config.local.yaml` (GitHub integration + backend.auth.externalAccess)
- `iac/environments/local/docker-compose.yml` (BACKSTAGE_PIPELINE_TOKEN + GITHUB_TOKEN)
- `prodops/artifacts/experiments/006-payments-api-integration/experiment.md` (concluído)
