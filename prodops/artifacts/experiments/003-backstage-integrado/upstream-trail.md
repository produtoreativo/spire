# EXP-003 — Upstream Trail (Backstage Integrado)

Experimento: [experiment.md](experiment.md)

---

# History

## 2026-08-26

### Activity

Experimento iniciado e concluído na mesma sessão.

### Summary

EXP-002 validou infraestrutura. EXP-003 começa com Fase 1: build da imagem Backstage custom
sem o bloqueio do nunjitsu (Yarn 4 security quarantine). A hipótese inicial era usar `npm` no
Dockerfile para contornar o quarantine.

**Resultado:** npm é inviável (protocolo `link:` do workspace Yarn 4). Yarn 4 funciona porque o
quarantine afeta apenas `nunjitsu@^0.6.1` — o OIDC plugin não depende dele.

Estratégia adotada: patch da imagem oficial `ghcr.io/backstage/backstage:latest` via:
1. `yarn add @backstage/plugin-auth-backend-module-oidc-provider@0.4.19` no subworkspace
2. Substituição de `dist/index.cjs.js` com versão registrando o OIDC plugin

### Issues Encontrados

| # | Problema | Causa | Solução |
|---|---|---|---|
| 1 | npm falha com `EUNSUPPORTEDPROTOCOL link:` | Root `package.json` usa protocolo Yarn `link:` incompatível com npm | Usar `yarn add` (disponível na imagem oficial) |
| 2 | Container Backstage crashes com `MODULE_NOT_FOUND` | `WORKDIR /app/packages/backend` não restaurado após `yarn add`; CMD tenta `/app/packages/backend/packages/backend` | Adicionar `WORKDIR /app` antes de `USER node` no Dockerfile |
| 3 | OIDC auth URL inclui `:8080` | `metadataUrl` via `keycloak:8080` (interno); Keycloak retorna issuer com `:8080` mesmo com `KC_HOSTNAME_URL` | Usar URL pública `keycloak.spire.localhost` + `extra_hosts: host-gateway` |
| 4 | Backstage ECONNREFUSED na inicialização | Race condition: Backstage e Keycloak reiniciados simultaneamente; OIDC library cacheou erro | Reiniciar apenas o Backstage após Keycloak saudável |
| 5 | Paths de catálogo quebrados (`/examples/entities.yaml`) | Paths relativos em `app-config.local.yaml` resolvidos errado (`../../examples` → `/examples`) | Usar paths absolutos `/app/examples/entities.yaml` |

### Validações Executadas

```
# Backstage healthcheck
GET http://backstage.spire.localhost/healthcheck → 200 OK

# OIDC redirect (sem :8080)
GET http://backstage.spire.localhost/api/auth/oidc/start?env=development
→ 302 Location: http://keycloak.spire.localhost/realms/spire/protocol/openid-connect/auth
  ?client_id=backstage&scope=openid%20profile%20email&response_type=code
  &redirect_uri=http%3A%2F%2Fbackstage.spire.localhost%2Fapi%2Fauth%2Foidc%2Fhandler%2Fframe
  &code_challenge_method=S256

# TechDocs S3 (log do container)
techdocs info Creating AWS S3 Bucket publisher for TechDocs
techdocs info Successfully connected to the AWS S3 bucket spire-artifacts.

# SeaweedFS IAM
auth_credentials.go Loaded 2 identities, 2 accounts, 1 access keys. Auth enabled: true

# OTel Collector
POST http://localhost:4318/v1/traces → 200 OK

# Todos os serviços
spire-backstage        Up (healthy)
spire-keycloak         Up (healthy)
spire-kong             Up (healthy)
spire-postgres         Up (healthy)
spire-redis            Up (healthy)
spire-seaweedfs-filer  Up (healthy)
spire-seaweedfs-master Up (healthy)
spire-seaweedfs-s3     Up (healthy)
spire-seaweedfs-volume Up (healthy)
spire-traefik          Up
spire-otel-collector   Up

# Rotas Traefik ativas
backstage.spire.localhost     → enabled
keycloak.spire.localhost      → enabled
kong-admin.spire.localhost    → enabled
api.spire.localhost           → enabled
seaweedfs.spire.localhost     → enabled
artifacts.spire.localhost     → enabled
```

### Decisions Registradas

| # | Decisão | Escolha |
|---|---|---|
| D1 | Tool para instalar plugins Backstage | `yarn add` (Yarn 4) — npm incompatível com workspace `link:` |
| D2 | Resolução de hostname Keycloak para OIDC | `extra_hosts: keycloak.spire.localhost:host-gateway` |
| D3 | Publisher TechDocs | `awsS3` com `endpoint: http://seaweedfs-s3:8333` e `s3ForcePathStyle: true` |
| D4 | OTel configuração Backstage | Env vars padrão `OTEL_*` — zero configuração de código |
| D5 | Kong JWT local | Out of scope — plugin `openid-connect` é Enterprise; alternativa EXP-005 |

### Artifacts Updated

- `iac/environments/local/backstage/Dockerfile` (criado)
- `iac/environments/local/backstage/patches/index.cjs.js` (criado)
- `iac/environments/local/backstage/app-config.local.yaml` (criado)
- `iac/environments/local/seaweedfs/s3-config.json` (criado)
- `iac/environments/local/docker-compose.yml` (atualizado — Backstage com OIDC/S3/OTel)
- `iac/environments/local/.env.example` (atualizado — SeaweedFS vars)
- `iac/environments/local/Makefile` (atualizado — URLs SeaweedFS)
- `prodops/artifacts/experiments/003-backstage-integrado/experiment.md` (concluído)

### Decision

EXP-003 concluído. Stack local com Backstage integrado ao Keycloak (OIDC), SeaweedFS (TechDocs S3)
e OTel Collector validado. Kong JWT adiado para EXP-005. Próximo: EXP-004 (plugins Spire de negócio).
