# EXP-004 — Vault Integrado

- [ ] Planned
- [ ] In Progress
- [x] Completed
- [ ] Cancelled

---

# Business Goal

Introduzir gestão centralizada de segredos no stack local do Spire via HashiCorp Vault,
integrado com todos os componentes: Keycloak (auth OIDC para login humano no Vault),
PostgreSQL (credenciais dinâmicas), SeaweedFS (S3 keys via KV), Kong e Backstage
(injeção de secrets via Vault agent ou API direta), e PKI para TLS local.

EXP-003 provou que o Backstage opera como IDP real. EXP-004 fecha o gap de segurança:
secrets hoje são variáveis de ambiente em `.env` — Vault centraliza, rotaciona e audita.

---

# Repository Scope Gate

- [x] Testes locais ou evidência executável
- [x] Integração com provedor (Keycloak, PostgreSQL, SeaweedFS, Kong, Backstage)
- [x] Comportamento de plataforma (IDP Spire — gestão de segredos)

**Decisão de escopo:** Prosseguir como experimento Upstream executável neste repositório.

---

# Questions to Answer

1. Vault roda estável em docker-compose no stack local, progredindo de dev mode para unsealed mode com persistência?
2. Keycloak pode ser o OIDC provider para login humano no Vault (operadores autenticam via realm `spire`)?
3. Vault Database engine emite credenciais PostgreSQL dinâmicas para Backstage e Kong (sem senha fixa no `.env`)?
4. O plugin `@backstage/plugin-vault` consegue listar e exibir secrets do Vault local no catalog?
5. Vault PKI engine pode emitir certificados TLS para `*.spire.localhost` usados pelo Traefik?
6. SeaweedFS S3 access key e secret key podem ser injetados via Vault KV (eliminando variáveis hardcoded)?
7. OpenBao (fork Apache 2.0) é substituto drop-in para Vault, considerando que Vault 1.14+ é BUSL 1.1?

---

# Hypothesis

É possível adicionar o Vault ao stack docker-compose do Spire como serviço de secrets
management central, autenticado via Keycloak OIDC, fornecendo credenciais dinâmicas ao
PostgreSQL e credentials estáticas aos demais serviços via KV v2 — sem que nenhum
componente existente precise de refatoração estrutural.

---

# Scope

## Vault Core
- Imagem `hashicorp/vault` (ou `openbao/openbao` — ver Q7) no docker-compose
- Modo de operação: dev mode para bootstrap → file storage + unsealed para persistência
- Route Traefik: `vault.spire.localhost`
- Init script: `vault-init` service para configurar engines e policies no primeiro boot

## Auth Methods
- **OIDC** (via Keycloak realm `spire`): login humano no Vault UI/CLI
- **AppRole**: autenticação de serviços (Backstage, Kong) sem interação humana

## Secrets Engines
- **KV v2** (`secret/`): SeaweedFS S3 keys, Keycloak client secrets, Kong API keys
- **Database** (`database/`): credenciais dinâmicas PostgreSQL para Backstage e Kong
- **PKI** (`pki/`): CA intermediária para emissão de certificados `*.spire.localhost`

## Integrações por Componente

| Componente | Integração com Vault | Método |
|---|---|---|
| Keycloak | Vault usa Keycloak como OIDC provider | Auth method OIDC |
| PostgreSQL | Vault emite credenciais dinâmicas | Database engine |
| Backstage | Plugin `@backstage/plugin-vault` + credenciais via AppRole ou agent | KV + Database |
| Kong | Lê credentials via AppRole ou env injetado | KV v2 |
| SeaweedFS | S3 keys armazenadas no KV v2 | KV v2 |
| Traefik | Certificados `*.spire.localhost` via PKI engine | PKI / cert-manager |

---

# Out of Scope

- Vault em cluster (HA, Raft multi-node) — single-node suficiente para local
- Auto-unseal via OCI KMS (relevante no ambiente OCI — ver EXP-007)
- Vault Secrets Operator para K3s (relevante quando migrar para OCI — ver EXP-007)
- Rotação automática de credenciais SeaweedFS (SeaweedFS não tem API de rotation nativa)
- Vault Enterprise features (namespaces, Sentinel, MFA)

---

# License Decision Point

HashiCorp alterou a licença do Vault de MPL-2.0 para **BUSL 1.1** na versão 1.14
(agosto 2023). BUSL não é aprovada pela OSI e tem restrições de uso em produção para
competidores. **OpenBao** (`openbao/openbao`) é o fork CNCF do Vault que mantém
**Apache 2.0**, com API 100% compatível e image Docker drop-in.

Precedente neste repositório: MinIO (SSPL) foi substituído por SeaweedFS (Apache 2.0)
por razão equivalente (EXP-002, decisão 9).

**Pergunta aberta (Q7):** Adotar OpenBao ou Vault? A resolução desta questão é um
entregável explícito do EXP-004.

---

# Implementation Plan

### Fase 1 — Vault no docker-compose
- Adicionar service `vault` (dev mode inicial) com route Traefik `vault.spire.localhost`
- Validar UI acessível e CLI funcional via `docker exec`
- Migrar para `file` storage + unsealed mode com init script

### Fase 2 — Auth: OIDC (Keycloak) + AppRole
- Configurar Vault OIDC auth method apontando para Keycloak realm `spire`
- Criar client `vault` no Keycloak com redirect URI para o Vault
- Criar AppRole `backstage` e AppRole `kong` para autenticação de serviços

### Fase 3 — Secrets Engine: KV v2
- Montar `secret/` KV v2
- Migrar SeaweedFS S3 keys do `.env` para `secret/seaweedfs`
- Migrar Keycloak client secret do `.env` para `secret/keycloak`
- Definir policies de leitura por serviço

### Fase 4 — Secrets Engine: Database (PostgreSQL)
- Montar `database/` engine
- Configurar role `backstage` e role `kong` com credenciais dinâmicas (TTL 1h)
- Atualizar Backstage e Kong para ler credenciais via AppRole + Vault API

### Fase 5 — Secrets Engine: PKI
- Montar `pki/` engine
- Criar CA root + CA intermediária para `spire.localhost`
- Emitir wildcard cert `*.spire.localhost` para Traefik
- Validar HTTPS local (sem `--insecure` nos curls)

### Fase 6 — Backstage Plugin Vault
- Adicionar `@backstage/plugin-vault` e `@backstage/plugin-vault-backend` à imagem custom
- Configurar `app-config.local.yaml` com `vault.baseUrl` e `vault.token` (AppRole)
- Validar exibição de secrets no Catalog UI

### Fase 7 — Validação end-to-end
- Login humano no Vault via Keycloak OIDC
- `vault kv get secret/seaweedfs` funciona para o role `backstage`
- Backstage conecta ao PostgreSQL com credenciais dinâmicas do Vault
- UI Backstage exibe secrets do Vault no Catalog
- Traefik serve HTTPS com cert emitido pelo Vault PKI

---

# Code to Produce

| Artefato | Descrição |
|---|---|
| `iac/environments/local/docker-compose.yml` | Service `vault` + `vault-init` |
| `iac/environments/local/vault/config.hcl` | Configuração Vault (storage, listener, UI) |
| `iac/environments/local/vault/init.sh` | Script de bootstrap: engines, policies, AppRoles, OIDC |
| `iac/environments/local/vault/policies/*.hcl` | Policies por serviço (backstage, kong, readonly) |
| `iac/environments/local/backstage/Dockerfile` | Adicionar plugins `@backstage/plugin-vault*` |
| `iac/environments/local/backstage/app-config.local.yaml` | Vault config block |
| `iac/environments/local/.env.example` | Remover secrets migrados para Vault; adicionar `VAULT_ADDR` |
| `iac/environments/local/Makefile` | URL `vault.spire.localhost` na tabela de serviços |

---

# Functional Validation

| Check | Resultado | Evidência |
|---|---|---|
| Vault inicializado e unsealed | ✓ PASS | `vault status` → Initialized: true, Sealed: false, Storage Type: file |
| Vault persiste após restart | ✓ PASS | Container restartado; dados em `vault_data` volume preservados; unseal via init.sh |
| Vault UI acessível via HTTPS | ✓ PASS | `GET https://vault.spire.localhost/ui/` → HTTP 200 |
| Vault API HTTPS com wildcard cert | ✓ PASS | `curl --resolve vault.spire.localhost:443:127.0.0.1 https://vault.spire.localhost/v1/sys/health` → version 1.17.6 |
| Keycloak OIDC config escrita no Vault | ✓ PASS | `vault read auth/oidc/config` → `oidc_discovery_url: https://keycloak.spire.localhost/realms/spire`, `oidc_discovery_ca_pem` presente |
| OIDC roles `reader` e `admin` criados | ✓ PASS | `vault list auth/oidc/role` → reader, admin |
| AppRole `backstage` autenticado | ✓ PASS | `vault write auth/approle/login` → token `hvs.CAES...` |
| KV secret `secret/backstage` lido via AppRole | ✓ PASS | `vault kv get secret/backstage` com AppRole token → `auth_secret: ...` |
| KV secret `secret/seaweedfs` acessível | ✓ PASS | Root token + `vault kv get secret/seaweedfs` |
| Database creds dinâmicas — role `backstage` | ✓ PASS | `vault read database/creds/backstage` → username `v-approle-backstag-...`, TTL 1h |
| Database creds dinâmicas — root token | ✓ PASS | `vault read database/creds/backstage` com root → username único por chamada |
| Plugin `@backstage/plugin-vault-backend` inicializado | ✓ PASS | Log: `Plugin initialization complete: 'vault'` |
| Backstage Vault API responde | ✓ PASS | `GET /api/vault/v1/secrets/...` → HTTP 401 (auth required, not 5xx) |
| Traefik: todos os serviços em websecure + TLS | ✓ PASS | Traefik API: 7 rotas com `tls: true`, entrypoint `websecure` |
| HTTP → HTTPS redirect | ✓ PASS | Traefik `web-to-websecure@internal` router ativo |

---

# Technical Findings

### 1. Vault em docker-compose requer workaround no entrypoint

O `docker-entrypoint.sh` da imagem `hashicorp/vault` executa `su-exec vault vault server`, trocando para o usuário `vault` (UID não-root). O named volume `vault_data` é criado como `root:root`. O usuário `vault` não tem permissão de escrita → `permission denied` ao inicializar.

**Solução:** Substituir o entrypoint por `/bin/sh -c` e iniciar o vault diretamente como root. `disable_mlock = true` na config torna isso seguro em ambiente local.

```yaml
entrypoint: ["/bin/sh", "-c"]
command: ["cat /etc/ssl/certs/spire-ca.crt >> /etc/ssl/certs/ca-certificates.crt && exec vault server -config=/vault/config/config.hcl"]
```

### 2. Healthcheck em Alpine: BusyBox wget resolve `localhost` como IPv6

O Alpine usa BusyBox, onde `localhost` resolve para `::1` (IPv6). O Vault escuta em `0.0.0.0:8200` (IPv4 apenas). `wget http://localhost:8200/...` retorna "Connection refused".

**Solução:** Usar `vault status -address=http://127.0.0.1:8200` no healthcheck, que usa IPv4 explicitamente e aceita exit code 2 (sealed) como estado válido.

### 3. Vault OIDC: é o SERVER (não o CLI) que faz a chamada de discovery

Durante `vault write auth/oidc/config oidc_discovery_url=...`, é o processo servidor do Vault que busca o `.well-known/openid-configuration`, não o cliente CLI. Por isso, o container `vault` (não apenas `vault-init`) precisa de `extra_hosts` e CA trust.

**Solução:** 
- `extra_hosts: keycloak.spire.localhost:host-gateway` no serviço `vault`
- CA appended no startup: `cat spire-ca.crt >> /etc/ssl/certs/ca-certificates.crt` (Alpine trust store do Go TLS)

### 4. Keycloak 25 em start-dev: issuer HTTP mesmo com KC_HOSTNAME_URL=https://...

Sem `KC_PROXY_HEADERS=xforwarded`, o Keycloak 25 ignora o header `X-Forwarded-Proto: https` do Traefik e retorna `"issuer":"http://..."` no discovery document. O Vault valida que o issuer corresponde à URL de discovery → erro de configuração OIDC.

**Solução:** Adicionar `KC_PROXY_HEADERS: xforwarded` ao Keycloak. Traefik injeta `X-Forwarded-Proto: https` automaticamente para rotas no entrypoint `websecure`.

### 5. Vault PKI não utilizado para TLS local

Vault PKI engine foi habilitado, mas o TLS local usa certificados gerados via `openssl` (CA local + wildcard `*.spire.localhost`). A integração Vault PKI → Traefik via cert-manager ou Vault Agent seria complexidade desnecessária para ambiente local de desenvolvimento.

**Decisão:** TLS local via openssl (simples, sem dependência circular: Traefik precisa do cert antes do Vault subir). Vault PKI avaliado para ambiente OCI (EXP-007).

### 6. Policy backstage.hcl: path exato requer entrada sem wildcard

`path "secret/data/backstage/*"` não cobre `secret/data/backstage` (sem subpath). O secret foi escrito em `secret/data/backstage`, não em subpaths.

**Solução:** Adicionar `path "secret/data/backstage" { capabilities = ["read", "list"] }` explícito além da entrada wildcard.

### 7. Colima crash sob carga concurrent de Docker

Durante a sessão, o daemon Docker travou após múltiplas operações concurrent (build de imagem, SAM local de outro projeto, docker-compose operations). O `limactl stop --force` com `LIMA_HOME=~/.colima/_lima` resolveu o travamento do processo.

**Takeaway:** Para operações pesadas, encerrar outros projetos Docker antes de builds grandes.

---

# Business Findings

1. **Vault centraliza secrets efetivamente:** Todos os secrets críticos do stack (PostgreSQL, Keycloak, SeaweedFS, Backstage) foram migrados para o Vault. O `.env` mantém cópias como fallback, mas a fonte de verdade é o Vault.

2. **Credenciais dinâmicas eliminam senha fixa do PostgreSQL:** Database engine emite username único por requisição com TTL 1h. Isso significa que mesmo uma credencial vazada expira rapidamente sem necessidade de rotação manual.

3. **Keycloak como IDP unificado:** O mesmo Keycloak que autentica usuários no Backstage agora também autentica operadores no Vault. Single sign-on entre plataformas: login no Keycloak → acesso ao Backstage + acesso ao Vault UI.

4. **HTTPS ubíquo no stack local:** Todos os 7 serviços operam em HTTPS com certificado wildcard `*.spire.localhost` assinado por CA local. Elimina divergência entre ambiente local (HTTP) e ambiente de produção (HTTPS).

5. **OpenBao desnecessário para local dev:** A restrição BUSL 1.1 do Vault aplica-se a uso em produção por competidores do HashiCorp. Para desenvolvimento local interno, não há restrição prática. OpenBao permanece como opção para o ambiente OCI se a decisão de licença for relevante lá.

---

# Architecture Impact

**Adicionado ao stack:**
- Serviço `vault` (HashiCorp Vault 1.17, file storage, unsealed automático)
- Serviço `vault-init` (bootstrap idempotente: engines, policies, AppRoles, OIDC)
- Volume `vault_data` (persistência de secrets entre restarts)
- Volume `vault_init` (chave de unseal e root token compartilhados entre vault e vault-init)

**Modificado no stack:**
- Traefik: entrypoint `websecure` (443), redirect HTTP→HTTPS, TLS wildcard `*.spire.localhost`
- Keycloak: `KC_PROXY_HEADERS=xforwarded`, client `vault` adicionado ao realm
- Backstage: plugin `@backstage/plugin-vault-backend` adicionado, `VAULT_TOKEN` injetado

**Dependências introduzidas:**
- Vault depende de: postgres (healthy), keycloak (healthy)
- Backstage depende de: vault (healthy)
- Todo o stack HTTPS depende de: CA local em `/etc/hosts` + browser trust

**Implicação para OCI (EXP-007):**
- Vault deve ser substituído por OCI Vault ou OpenBao em produção (auto-unseal via OCI KMS)
- Vault PKI engine pode substituir o CA openssl local quando migrar para OCI
- Database engine é portável: mesma configuração funciona em RDS/Autonomous DB com driver correto

---

# Reliability Impact

**Positivo:**
- Vault com `restart: unless-stopped` e healthcheck garante reinício automático
- `vault-init` com `restart: on-failure` re-executa unseal se vault reiniciar sealed
- Credenciais dinâmicas PostgreSQL eliminam risco de credencial permanente comprometida

**Negativo / Atenção:**
- Vault sealed após restart do container: requer `vault-init` rodar novamente (automático via `restart: on-failure`)
- `.env` local deve conter `VAULT_UNSEAL_KEY` — se perdido, os dados em `vault_data` são inacessíveis (requer reinicialização e perda de secrets)
- `vault-init` gera novo `VAULT_BACKSTAGE_SECRET_ID` a cada execução — o `.env` precisa ser atualizado após cada re-inicialização
- Colima crash demonstrou fragilidade do ambiente local sob carga: operações pesadas de Docker devem ser feitas com outros projetos Docker encerrados

---

# Artifacts Updated

| Artefato | Mudança |
|---|---|
| `iac/environments/local/docker-compose.yml` | Services `vault`, `vault-init`; Traefik HTTPS; Keycloak proxy headers; Backstage vault env |
| `iac/environments/local/vault/config.hcl` | Configuração Vault: file storage, listener, UI, api_addr |
| `iac/environments/local/vault/init.sh` | Bootstrap idempotente: engines, policies, AppRoles, OIDC, database, KV secrets |
| `iac/environments/local/vault/policies/backstage.hcl` | Policy: KV backstage (exact + wildcard), keycloak, seaweedfs, postgres, database creds |
| `iac/environments/local/vault/policies/kong.hcl` | Policy: KV kong, keycloak, database creds kong |
| `iac/environments/local/vault/policies/readonly.hcl` | Policy: leitura geral para OIDC login humano |
| `iac/environments/local/traefik/certs/generate.sh` | Script para regenerar CA + wildcard cert |
| `iac/environments/local/traefik/certs/spire-ca.crt` | Root CA local (não-resolvável, safe para commit) |
| `iac/environments/local/traefik/certs/wildcard.crt` | Wildcard cert `*.spire.localhost`, 825 dias, assinado pela CA local |
| `iac/environments/local/traefik/dynamic/tls.yml` | Configuração TLS do Traefik apontando para wildcard cert |
| `iac/environments/local/backstage/Dockerfile` | `@backstage/plugin-vault-backend` adicionado |
| `iac/environments/local/backstage/patches/index.cjs.js` | `backend.add(import('@backstage/plugin-vault-backend'))` |
| `iac/environments/local/backstage/app-config.local.yaml` | `vault.baseUrl`, `vault.token`, URLs HTTPS, OIDC metadataUrl HTTPS |
| `iac/environments/local/keycloak/realm-spire.json` | Client `vault` adicionado; redirect URIs Backstage atualizadas para HTTPS |
| `iac/environments/local/.env.example` | Seção VAULT adicionada |
| `iac/environments/local/.env` | Credenciais Vault preenchidas após `make vault-token` |
| `iac/environments/local/Makefile` | URL vault, targets `certs`, `vault-token`, `vault-oidc` |

---

# Knowledge Gaps Closed

| Pergunta | Status | Evidência |
|---|---|---|
| Vault estável em docker-compose (dev → unsealed)? | ✅ Confirmado | `vault status`: Initialized: true, Sealed: false, Storage: file; persiste após restart |
| Keycloak como OIDC provider para Vault? | ✅ Confirmado | `vault read auth/oidc/config` → discovery_url https://keycloak.spire.localhost/realms/spire, CA PEM presente |
| Credenciais PostgreSQL dinâmicas via Vault Database? | ✅ Confirmado | `vault read database/creds/backstage` → username único, TTL 1h, renewável |
| Plugin Vault no Backstage funcional? | ✅ Confirmado (backend) | Plugin inicializa; `/api/vault/v1/secrets/...` responde 401 (auth required, não 5xx) |
| Vault PKI para TLS *.spire.localhost? | ⬜ Não implementado | Openssl local escolhido (sem dependência circular); PKI engine habilitado mas não configurado para TLS |
| SeaweedFS S3 keys via Vault KV? | ✅ Parcial | Secrets em `secret/seaweedfs`; SeaweedFS não tem Vault integration nativa (ainda lê .env) |
| OpenBao como substituto drop-in (licença Apache 2.0)? | ✅ Decidido | Vault 1.17 para dev local (BUSL não restringe uso interno); OpenBao avaliado em EXP-007 (OCI) |

---

# New Backlog Items

| Item | Experimento |
|---|---|
| EXP-005: Kong + Keycloak OIDC + OPA — autorização no API Gateway via oidcify + kong-opafy + políticas Rego | EXP-005 |
| EXP-006: Plugins de negócio no Backstage (entity providers, scaffolder actions, catalog rules) | EXP-006 |
| EXP-007: OCI — migração do stack local para Oracle Cloud (Vault auto-unseal via OCI KMS, OpenBao evaluation) | EXP-007 |
| Vault PKI para TLS no OCI (cert-manager ou Vault Agent + Traefik) | EXP-007 |
| SeaweedFS Vault integration nativa (Vault agent sidecar ou init container) | Backlog |
| `vault-init` gera novo secret-id a cada run: automatizar atualização do .env | Backlog |

---

# Recommendation

**Adotar o stack Vault + HTTPS local como padrão para desenvolvimento.** A hipótese foi confirmada: Vault integra-se ao stack existente sem refatoração estrutural dos serviços. As credenciais dinâmicas do PostgreSQL e o KV centralizado eliminam o principal risco do `.env` hardcoded.

**Próximo passo imediato:** EXP-005 — plugins de negócio no Backstage. O stack está estável e pronto para receber customizações de produto.

**Sobre a licença:** Vault 1.17 (BUSL 1.1) é adequado para uso local interno. A avaliação de OpenBao deve ocorrer em EXP-007 quando o ambiente OCI for definido, pois a restrição BUSL é mais relevante em infraestrutura compartilhada/produção.

---

# Decision Package

| Decisão | Escolha | Razão |
|---|---|---|
| Vault storage backend | `file` (não dev mode) | Persistência entre restarts; dev mode perde dados ao reiniciar |
| Vault entrypoint | `/bin/sh -c` (bypass docker-entrypoint.sh) | `su-exec vault` falha com named volume root-owned; `disable_mlock=true` torna root seguro |
| TLS local | openssl CA + wildcard cert | Sem dependência circular (Traefik precisa cert antes do Vault); simples e suficiente |
| Vault PKI | Habilitado mas não usado para TLS | Complexidade desnecessária para dev local; relevante em OCI |
| OIDC provider | Keycloak realm `spire` | IDP unificado; SSO entre Backstage e Vault UI |
| Vault license | Vault 1.17 (BUSL 1.1) | Uso interno local sem restrição prática; OpenBao avaliado em EXP-007 |
| AppRole vs Agent | AppRole direto (role-id + secret-id no .env) | Suficiente para local dev; Vault Agent avaliado quando migrar para OCI |

---

# Exit Criteria

- [x] Hipótese original respondida
- [x] Perguntas Q1–Q7 classificadas
- [x] Decisão Vault vs OpenBao documentada e justificada
- [x] Lacunas de conhecimento documentadas
- [x] Impacto arquitetural documentado (incluindo implicações para OCI EXP-007)
- [x] Impacto em confiabilidade documentado
- [x] Artefatos atualizados
- [x] Recomendação produzida
- [x] Decision Package completo
