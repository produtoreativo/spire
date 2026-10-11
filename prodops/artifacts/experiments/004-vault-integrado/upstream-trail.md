# EXP-004 — Upstream Trail (Vault Integrado)

Experimento: [experiment.md](experiment.md)

---

# History

## 2026-08-26

### Activity

Experimento planejado. Plano de experimentos reformulado para inserir Vault como EXP-004,
antes dos plugins de negócio (agora EXP-005).

### Summary

EXP-003 fechou as integrações centrais do Backstage (OIDC, TechDocs S3, OTel). O gap
de segurança remanescente é que todos os secrets ainda vivem em variáveis de ambiente no
`.env` — sem rotação, sem auditoria, sem controle de acesso por serviço.

EXP-004 endereça esse gap adicionando HashiCorp Vault (ou OpenBao — Q7 a resolver)
como camada de secrets management centralizada, integrada com Keycloak (OIDC),
PostgreSQL (credenciais dinâmicas), Backstage (plugin), Kong (AppRole), SeaweedFS
(KV v2) e Traefik (PKI para TLS local).

### Decision

Experimento aprovado para execução. Aguardando início da jornada Upstream.

### Artifacts Updated

- `prodops/artifacts/experiments/004-vault-integrado/experiment.md` (criado)
- `prodops/artifacts/experiments/004-vault-integrado/upstream-trail.md` (criado)
- `prodops/artifacts/experiments/003-backstage-integrado/experiment.md` (backlog items renumerados)

---

### Activity (continuação — mesma data, sessão 2)

Implementação completa do EXP-004. Todas as fases executadas e validadas.

**Fase 1 — Vault no docker-compose:**
- Serviços `vault` e `vault-init` adicionados
- Vault rodando com file storage, unsealed automático
- 3 workarounds descobertos e aplicados: entrypoint root, healthcheck IPv4, CA trust

**Fase 2 — Auth: OIDC (Keycloak) + AppRole:**
- `KC_PROXY_HEADERS=xforwarded` adicionado ao Keycloak para issuer HTTPS
- `extra_hosts` + CA append no entrypoint do Vault para OIDC discovery funcionar
- OIDC configurado: roles `reader` e `admin`; AppRoles `backstage` e `kong`

**Fase 3 — KV v2:**
- Secrets escritos: `secret/seaweedfs`, `secret/keycloak`, `secret/postgres`, `secret/backstage`
- Policies por serviço criadas e validadas

**Fase 4 — Database engine (PostgreSQL):**
- Roles dinâmicos `backstage` e `kong` com TTL 1h
- Credenciais geradas via root token e via AppRole — ambos funcionando

**Fase 5 — SSL/TLS:**
- CA local + wildcard `*.spire.localhost` gerados via openssl
- Todos os 7 serviços em HTTPS (Traefik websecure + TLS)
- Vault PKI não usado para TLS local (sem dependência circular)

**Fase 6 — Backstage Plugin Vault:**
- `@backstage/plugin-vault-backend` adicionado ao Dockerfile
- Plugin inicializa sem erros; API responde 401 (auth required)

**Fase 7 — Validação end-to-end (CLI):**
- Vault health: initialized=true, sealed=false
- OIDC config presente com CA PEM e HTTPS discovery URL
- AppRole autentica e lê KV `secret/backstage` ✓
- AppRole gera creds dinâmicas PostgreSQL `database/creds/backstage` ✓
- Backstage plugin `vault` inicializado no startup ✓

### Decision

**Hipótese confirmada.** Vault integra-se ao stack sem refatoração estrutural. Credenciais dinâmicas eliminam senha fixa do PostgreSQL. HTTPS ubíquo no stack local.

**Decisão de licença:** Vault 1.17 (BUSL 1.1) para dev local. OpenBao avaliado em EXP-007.

**Próximo:** EXP-005 — plugins de negócio no Backstage.

### Artifacts Updated

- `iac/environments/local/docker-compose.yml`
- `iac/environments/local/vault/config.hcl` (novo)
- `iac/environments/local/vault/init.sh` (novo)
- `iac/environments/local/vault/policies/backstage.hcl` (novo, corrigido path exato)
- `iac/environments/local/vault/policies/kong.hcl` (novo)
- `iac/environments/local/vault/policies/readonly.hcl` (novo)
- `iac/environments/local/traefik/certs/generate.sh` (novo)
- `iac/environments/local/traefik/certs/spire-ca.crt` / `wildcard.crt` (novos)
- `iac/environments/local/traefik/dynamic/tls.yml` (novo)
- `iac/environments/local/backstage/Dockerfile`
- `iac/environments/local/backstage/patches/index.cjs.js`
- `iac/environments/local/backstage/app-config.local.yaml`
- `iac/environments/local/keycloak/realm-spire.json`
- `iac/environments/local/.env.example` / `.env`
- `iac/environments/local/Makefile`
- `prodops/artifacts/experiments/004-vault-integrado/experiment.md` (Completed)
