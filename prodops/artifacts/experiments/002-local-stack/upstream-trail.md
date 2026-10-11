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
- **Fix:** Adicionados labels `service=` explícitos para Kong (2 routers). MinIO substituído por SeaweedFS (ver issue 9).

### 10. SeaweedFS S3 — anonymous write bloqueado
- **Sintoma:** PUT/DELETE via S3 API retorna 403. GET `/` e GET `/bucket/` também retornam 403.
- **Causa:** SeaweedFS S3 sem IAM config bloqueia write anônimo por design. "Auth enabled: false" libera leitura mas não escrita.
- **Para EXP-002:** Aceito — stack de infraestrutura validado. Upload via filer REST API funciona sem credenciais.
- **Decisão:** EXP-003 configura IAM com access key + secret para o S3 gateway.

### 9. MinIO SSPL — substituído por SeaweedFS (Apache 2.0)
- **Motivo:** MinIO usa licença SSPL (Server Side Public License), que não é OSI-approved open source.
  Não aprovado para uso em stacks de referência do Spire.
- **Alternativas avaliadas:** LocalStack (requer conta desde março/2026), Garage (AGPL-3.0, single-container),
  SeaweedFS (Apache 2.0, S3-compatible, multi-component, comunidade ativa).
- **Decisão:** SeaweedFS — imagem `chrislusf/seaweedfs`, 4 componentes (master + volume + filer + s3 gateway).
- **Fix:** Substituídos serviços `minio` + `minio-init` por `seaweedfs-master`, `seaweedfs-volume`,
  `seaweedfs-filer`, `seaweedfs-s3`, `seaweedfs-init`. Volume `minio_data` → `seaweedfs_master` + `seaweedfs_data`.
  `.env.example`: removidas variáveis `MINIO_ROOT_USER`/`PASSWORD`, adicionada `SEAWEEDFS_BUCKET`.
  Makefile: URL atualizada para `seaweedfs.spire.localhost` e `artifacts.spire.localhost`.
- **Acesso dev local:** modo anônimo S3 (sem s3.json). Auth em EXP-003.

### 8. Backstage healthcheck — `curl` não disponível na imagem oficial
- **Sintoma:** Container sempre em "starting" — healthcheck usava `curl` que não existe no `ghcr.io/backstage/backstage` (Node.js image).
  Traefik respeita o healthcheck Docker e não adiciona o router enquanto está em "starting".
- **Fix:** Healthcheck via `node -e "require('http').get('http://localhost:7007/healthcheck', ...)"`.
  Aplicado tanto no `backstage/Dockerfile` quanto no `docker-compose.yml` (compose override tem precedência).

### 7. Backstage build via `@backstage/create-app` bloqueado pelo Yarn 4 quarantine
- **Sintoma:** `yarn install` falha — `nunjitsu@^0.6.1` quarantinado por security advisory.
  `YARN_ENABLE_HARDENED_MODE=0` não contorna a quarentena.
- **Decisão:** Usar `ghcr.io/backstage/backstage:latest` (imagem oficial pré-construída) para EXP-002.
  EXP-003 criará imagem customizada com plugins Spire, resolvendo a dependência nunjitsu.

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

### ✅ Serviços healthy (validação final com SeaweedFS)

| Serviço                | Status    | Validação |
|------------------------|-----------|-----------|
| Traefik v3.1           | up        | Dashboard em `localhost:8080`; 8 routers enabled |
| PostgreSQL 16          | healthy   | `pg_isready` OK; DBs: spire, keycloak, kong + 13 backstage plugins |
| Redis 7                | healthy   | `redis-cli ping` → PONG |
| SeaweedFS master 4.13  | healthy   | Cluster status OK em `localhost:9333` |
| SeaweedFS volume 4.13  | healthy   | Volume server OK; `-ip.bind=0.0.0.0` obrigatório |
| SeaweedFS filer 4.13   | healthy   | Filer UI em `seaweedfs.spire.localhost` (200) |
| SeaweedFS S3 4.13      | healthy   | Gateway em `artifacts.spire.localhost` (403 anon = esperado) |
| Kong 3.7               | healthy   | Admin API em `kong-admin.spire.localhost` (200) |
| Keycloak 25.0          | healthy   | Realm `spire` importado; OIDC discovery OK (200) |
| Backstage latest       | healthy   | UI em `backstage.spire.localhost` (200) |
| OTEL Collector         | up        | gRPC :4317 e HTTP :4318 ouvindo |

### ✅ Integrações validadas

| Integração | Resultado |
|------------|-----------|
| PostgreSQL → múltiplos DBs via init script | OK |
| SeaweedFS → bucket `spire-artifacts` criado via `weed shell` + `fs.mkdir` | OK |
| SeaweedFS filer → UI acessível em `seaweedfs.spire.localhost` | OK (200) |
| SeaweedFS S3 → gateway acessível em `artifacts.spire.localhost` | OK (403 anon = correto) |
| Keycloak → conectado ao PostgreSQL (keycloak DB) | OK |
| Keycloak → realm `spire` importado com clients e usuários | OK |
| Keycloak OIDC → `/.well-known/openid-configuration` acessível | OK (200) |
| Traefik → backstage.spire.localhost | OK (200) |
| Traefik → keycloak.spire.localhost | OK (200) |
| Traefik → api.spire.localhost (Kong proxy) | OK (401 sem token = correto) |
| Traefik → kong-admin.spire.localhost | OK (200) |
| Traefik → seaweedfs.spire.localhost | OK (200) |
| Traefik → artifacts.spire.localhost | OK (403 anon = correto) |
| Kong → proxy para Backstage com rate-limiting + correlation-id | OK (401 esperado) |
| Backstage → PostgreSQL (13 plugin databases) | OK |

### ✅ Backstage (EXP-002 completo)

| Item | Status |
|------|--------|
| Backstage → healthy (ghcr.io/backstage/backstage:latest) | OK |
| Backstage → PostgreSQL (13 plugin databases criados) | OK |
| Backstage → healthcheck via `node http` (sem curl) | OK |
| Traefik → backstage.spire.localhost | OK (router enabled) |
| Kong → api.spire.localhost/backstage/* | OK (proxy funcionando, 401 esperado) |
| Backstage API 401 sem token | OK (autenticação necessária — comportamento correto) |

### ⏳ EXP-003

| Item | Status |
|------|--------|
| Backstage → autenticação via Keycloak OIDC | Requer `@backstage/plugin-auth-backend-module-oidc-provider` |
| Kong JWT validation via Keycloak | Kong Enterprise ou solução alternativa (lua-resty-oidc) |
| Custom Backstage image com plugins Spire | Build próprio substitui ghcr.io/backstage/backstage |

---

## /etc/hosts Requirements

Para acesso via browser (necessário adicionar manualmente):

```
127.0.0.1 backstage.spire.localhost keycloak.spire.localhost
127.0.0.1 kong-admin.spire.localhost api.spire.localhost
127.0.0.1 seaweedfs.spire.localhost artifacts.spire.localhost
```

## Links locais (após /etc/hosts configurado)

| Serviço | URL |
|---------|-----|
| Traefik Dashboard | http://localhost:8080/dashboard/ |
| Backstage | http://backstage.spire.localhost |
| Keycloak Admin | http://keycloak.spire.localhost/admin |
| Kong Admin | http://kong-admin.spire.localhost |
| Kong Proxy | http://api.spire.localhost |
| SeaweedFS UI | http://seaweedfs.spire.localhost |
| Artifacts (S3) | http://artifacts.spire.localhost |

Alternativa: `dnsmasq` com `address=/.spire.localhost/127.0.0.1` para wildcard automático.

---

## Decisões Tomadas

1. **Node 22** obrigatório para Backstage create-app latest (versão 20 bloqueada).
2. **Guest auth** para EXP-002 — Keycloak OIDC requer `@backstage/plugin-auth-backend-module-oidc-provider` (EXP-003).
3. **Kong sem JWT** para EXP-002 — Kong OSS DB-less não suporta JWKS dinâmico (EXP-003).
4. **APP_CONFIG_ env vars** para injeção de config no Backstage — mais confiável que `--config` flags com yarn workspaces.
5. **bash /dev/tcp** como healthcheck para Keycloak — único mecanismo sem curl/wget na imagem ubi9-micro.
6. **SeaweedFS** (Apache 2.0) substituiu MinIO (SSPL) — mesmo endpoint S3 em `artifacts.spire.localhost`, filer UI em `seaweedfs.spire.localhost`. Modo anônimo para dev local.
7. **SeaweedFS volume server** requer `-ip.bind=0.0.0.0` para que o healthcheck via `localhost` funcione. Sem isso, o process faz bind no IP da interface do container (não em loopback).
8. **SeaweedFS S3 healthcheck** — BusyBox wget retorna exit 1 tanto para HTTP 4xx quanto para connection refused. Fix: `! wget ... 2>&1 | grep -qF refused` distingue pelo texto do erro.
9. **SeaweedFS init** — `weed shell` não tem flag `-run`. Bucket criado via stdin: `echo "fs.mkdir /buckets/..." | weed shell -master=... -filer=...`.
