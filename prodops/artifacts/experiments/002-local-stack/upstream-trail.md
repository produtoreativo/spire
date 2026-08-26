# EXP-002 — Upstream Trail (Local Stack Validation)

## Session: 2026-08-25 / 2026-08-26

---

## Issues Found and Fixed

### 1. `docker compose` vs `docker-compose` (v1 compat)
- **Sintoma:** `make up` falha — sistema tem `docker-compose` v1 (5.1.4), não o plugin v2.
- **Fix:** `Makefile` — substituído `docker compose` por `docker-compose` em todos os targets.

### 2. MinIO healthcheck incorreto
- **Sintoma:** Healthcheck `mc ready local` falha pois `mc` não existe na imagem `minio/minio:latest`.
- **Fix:** Substituído por `curl -f http://localhost:9000/minio/health/live`.

### 3. Backstage placeholder não funcional
- **Sintoma:** Serviço `backstage` rodava `npx create-app` sem yarn install — container saía imediatamente.
- **Fix:** Criado `iac/environments/local/backstage/Dockerfile` com scaffold + yarn install.
  - `node:22-alpine` obrigatório — versão 20 rejeitada pelo `@backstage/create-app` latest.
  - `--path spire` obrigatório — versão atual não aceita argumento posicional.
  - Configuração injetada via `APP_CONFIG_` env vars (evita ambiguidade de path entre yarn v1/v2).

### 4. Keycloak healthcheck incorreto
- **Sintoma:** Container `unhealthy` mesmo com Keycloak rodando.
- **Causa raiz:** Imagem `quay.io/keycloak/keycloak:25.0` usa `ubi9-micro` — sem `curl` nem `wget`.
  Além disso, o CMD-SHELL usa `/bin/sh`, e `/dev/tcp` é feature exclusiva do `bash`.
  O endpoint de saúde fica na porta de management `9000`, não na porta HTTP principal `8080`.
- **Fix:** Healthcheck com `CMD bash -c 'exec 3<>/dev/tcp/localhost/9000 && ... grep -q 200'`.

### 5. Traefik v3 — múltiplos serviços por container
- **Sintoma:** Routers `kong-proxy`, `kong-admin`, `minio-api`, `minio-console` ausentes no Traefik.
  Log: `Router X cannot be linked automatically with multiple Services`.
- **Causa raiz:** Traefik v3 exige `traefik.http.routers.<name>.service=<name>` explícito quando
  um container define múltiplos named services via labels.
- **Fix:** Adicionados labels `service=` explícitos para Kong (2 routers) e MinIO (2 routers).

### 6. Kong JWT plugin incompatível com DB-less + Keycloak JWKS
- **Análise:** Kong OSS JWT plugin exige consumers com public keys pré-declaradas em kong.yml.
  Não suporta JWKS endpoint dinâmico (que é o que o Keycloak expõe).
  `openid-connect` plugin (que suporta JWKS) é Kong Enterprise.
- **Decisão:** Removido JWT plugin do kong.yml para EXP-002.
  Auth handled at Backstage level via Keycloak OIDC. Documentado como item para EXP-003.

### 7. `@backstage/create-app` API breaking changes
- **Sintoma:** `npx @backstage/create-app@latest --skip-install spire` falha com "too many arguments".
- **Fix:** Usar `--path spire` como flag nomeada.

---

## Validation Results (2026-08-26)

### ✅ Serviços healthy

| Serviço          | Status    | Validação |
|------------------|-----------|-----------|
| Traefik v3.1.7   | up        | Dashboard em `localhost:8080` |
| PostgreSQL 16    | healthy   | `pg_isready` OK; DBs criados: spire, keycloak, kong |
| Redis 7          | healthy   | `redis-cli ping` → PONG |
| MinIO latest     | healthy   | `curl /minio/health/live` OK; bucket `spire-artifacts` criado |
| Kong 3.7.1       | healthy   | Admin API responde em `kong-admin.spire.localhost` via Traefik |
| Keycloak 25.0.6  | healthy   | Realm `spire` importado; OIDC discovery OK |
| OTEL Collector   | up        | gRPC :4317 e HTTP :4318 ouvindo |

### ✅ Integrações validadas

| Integração | Resultado |
|------------|-----------|
| PostgreSQL → múltiplos DBs via init script | OK |
| MinIO → bucket criado pelo minio-init container | OK |
| Keycloak → conectado ao PostgreSQL (keycloak DB) | OK |
| Keycloak → realm `spire` importado com clients e usuários | OK |
| Keycloak OIDC → `/.well-known/openid-configuration` acessível | OK |
| Traefik → keycloak.spire.localhost | OK |
| Traefik → api.spire.localhost (Kong proxy) | OK |
| Traefik → kong-admin.spire.localhost | OK |
| Traefik → minio.spire.localhost (console) | OK |
| Traefik → artifacts.spire.localhost (MinIO API) | OK |
| Kong → proxy para Backstage com rate-limiting + correlation-id | OK (500 esperado sem Backstage) |

### ⏳ Pendente

| Item | Status |
|------|--------|
| Backstage build (node:22, yarn install) | Em andamento — 5-15 min |
| Backstage → PostgreSQL (spire DB) | Aguardando build |
| Backstage → healthcheck /healthcheck | Aguardando build |
| Backstage → autenticação via Keycloak OIDC | EXP-003 (plugin auth-module-oidc-provider) |
| Kong JWT validation via Keycloak | EXP-003 (Kong Enterprise ou solução alternativa) |

---

## /etc/hosts Requirements

Para acesso via browser (necessário adicionar manualmente):

```
127.0.0.1 backstage.spire.localhost keycloak.spire.localhost
127.0.0.1 kong-admin.spire.localhost api.spire.localhost
127.0.0.1 minio.spire.localhost artifacts.spire.localhost
```

Alternativa: `dnsmasq` com `address=/.spire.localhost/127.0.0.1` para wildcard automático.

---

## Decisões Tomadas

1. **Node 22** obrigatório para Backstage create-app latest (versão 20 bloqueada).
2. **Guest auth** para EXP-002 — Keycloak OIDC requer `@backstage/plugin-auth-backend-module-oidc-provider` (EXP-003).
3. **Kong sem JWT** para EXP-002 — Kong OSS DB-less não suporta JWKS dinâmico (EXP-003).
4. **APP_CONFIG_ env vars** para injeção de config no Backstage — mais confiável que `--config` flags com yarn workspaces.
5. **bash /dev/tcp** como healthcheck para Keycloak — único mecanismo sem curl/wget na imagem ubi9-micro.
