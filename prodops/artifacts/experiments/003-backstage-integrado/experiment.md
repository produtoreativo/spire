# EXP-003 — Backstage Integrado

- [x] Completed

---

# Business Goal

Validar que o Backstage pode operar como IDP real no stack local do Spire — com identidade via
Keycloak OIDC, artefatos TechDocs no SeaweedFS S3, rastreabilidade via OTEL e proteção de API
via Kong com validação JWT — tudo a partir de uma imagem Docker construída neste repositório.

EXP-002 provou que a infraestrutura sobe e se comunica. EXP-003 prova que o Backstage
participa ativamente dela.

---

# Repository Scope Gate

- [x] Testes locais ou evidência executável
- [x] Integração com provedor (Keycloak, SeaweedFS, Kong)
- [x] Comportamento de plataforma (IDP Spire)

**Decisão de escopo:** Prosseguir como experimento Upstream executável neste repositório.

---

# Questions to Answer

1. É possível construir uma imagem Backstage custom sem o bloqueio do nunjitsu (Yarn 4 quarantine)?
2. O `@backstage/plugin-auth-backend-module-oidc-provider` consegue autenticar via Keycloak realm `spire`?
3. O TechDocs pode publicar no SeaweedFS S3 (`artifacts.spire.localhost`) sem credenciais IAM configuradas?
4. O Backstage emite traces OTEL recebidos pelo Collector (`localhost:4318`)?
5. O Kong consegue validar JWTs emitidos pelo Keycloak sem Enterprise (alternativa OSS)?

---

# Hypothesis

É possível construir uma imagem Backstage customizada usando `npm` (evitando o Yarn 4 quarantine
do nunjitsu), instalar os plugins necessários e configurar todas as integrações locais via
`APP_CONFIG_` e `app-config.local.yaml`. O resultado é um Backstage funcional com login OIDC,
TechDocs no S3, traces OTel e API protegida via Kong.

**Status:** Parcialmente confirmada. OIDC, TechDocs S3 e OTel funcionam. npm não foi necessário:
Yarn 4 quarantine não bloqueia o OIDC plugin (apenas nunjitsu). Kong JWT não é viável em OSS DB-less.

---

# Scope

- Dockerfile custom com `@backstage/create-app` via `npm` (não yarn)
- Plugin `@backstage/plugin-auth-backend-module-oidc-provider` no backend
- `app-config.local.yaml` com OIDC, S3, OTel configurados
- `docker-compose.yml` atualizado com build local da imagem
- Keycloak: client `backstage` com redirect URIs corretos
- SeaweedFS S3: IAM mínimo (access key + secret) para TechDocs
- Kong: validação JWT via Keycloak JWKS com plugin `openid-connect` OSS ou alternativa

---

# Out of Scope

- Deploy em staging ou produção
- Plugins Spire de negócio (OBC/OpenAPI/AsyncAPI) — EXP-004
- Alta disponibilidade ou múltiplas réplicas
- Backstage Software Catalog populado com entidades reais

---

# Implementation

1. **Fase 1 — Imagem custom**: Dockerfile com `npm` para evitar nunjitsu. Registrar OIDC plugin.
2. **Fase 2 — Keycloak OIDC**: Configurar `auth.providers.oidc` com realm `spire`. Ajustar redirect URIs no realm.
3. **Fase 3 — TechDocs S3**: Configurar IAM no SeaweedFS + `techdocs.publisher.type: awsS3`.
4. **Fase 4 — OTel**: Configurar `@opentelemetry/sdk-node` no backend Backstage.
5. **Fase 5 — Kong JWT**: Investigar alternativa OSS ao plugin `openid-connect` Enterprise.
6. **Validação**: Login end-to-end, TechDocs, trace visível, API protegida.

---

# Code Produced

| Arquivo | Descrição |
|---|---|
| `iac/environments/local/backstage/Dockerfile` | Imagem custom: yarn add OIDC plugin + patch do entry point |
| `iac/environments/local/backstage/patches/index.cjs.js` | Entry point patched com `plugin-auth-backend-module-oidc-provider` |
| `iac/environments/local/backstage/app-config.local.yaml` | Config overrides: OIDC, TechDocs S3, OTel, database, catalog |
| `iac/environments/local/seaweedfs/s3-config.json` | IAM identities SeaweedFS S3 com `spire` user e `anonymous` read |
| `iac/environments/local/docker-compose.yml` | Backstage com env vars OIDC/S3/OTel, `extra_hosts` host-gateway, depends |

**Estratégia de build:** Patching da imagem oficial `ghcr.io/backstage/backstage:latest` em vez
de build from source. O backend compilado é um CJS monolítico com dynamic imports. A adição de
plugin requer: (1) `yarn add` do pacote no subworkspace, (2) patch do `dist/index.cjs.js`.

---

# Functional Validation

| Integração | Status | Evidência |
|---|---|---|
| Backstage healthcheck | ✅ | `GET /healthcheck → 200`, container `healthy` |
| Keycloak OIDC redirect | ✅ | `302 Location: http://keycloak.spire.localhost/realms/spire/protocol/openid-connect/auth` |
| TechDocs → SeaweedFS S3 | ✅ | Log: `Successfully connected to the AWS S3 bucket spire-artifacts` |
| OTel traces | ✅ | `POST /v1/traces → 200` no OTel Collector |
| SeaweedFS IAM | ✅ | `Loaded 2 identities, 1 access keys. Auth enabled: true` |
| Kong JWT OSS | ❌ | Não suportado em DB-less mode (documentado como out of scope) |
| Todos os serviços healthy | ✅ | 11 containers up/healthy, 6 rotas Traefik ativas |

---

# Technical Findings

1. **Yarn 4 quarantine é seletivo.** O bloqueio do Yarn 4 afeta `nunjitsu@^0.6.1` mas não
   contamina a árvore de dependências do OIDC plugin. `yarn add @backstage/plugin-auth-backend-module-oidc-provider`
   funciona dentro do subworkspace `/app/packages/backend` sem flags especiais.

2. **npm é incompatível com o workspace Yarn 4 do Backstage.** O `package.json` raiz usa
   protocolo `link:` (Yarn workspace). npm não o suporta e falha com `EUNSUPPORTEDPROTOCOL`
   mesmo instalando em subdiretório — npm caminha até o workspace raiz.

3. **Keycloak `KC_HOSTNAME_URL` não resolve o problema de issuer interno.** Requests
   de backchannel via `http://keycloak:8080` retornam issuer com `:8080` mesmo com
   `KC_HOSTNAME_URL` configurado. A solução é: `metadataUrl` via URL pública +
   `extra_hosts: keycloak.spire.localhost:host-gateway` para rotear pelo Traefik do host.

4. **`WORKDIR` deve ser restaurado após instalação de plugin.** `yarn add` no subworkspace
   deixa o `WORKDIR` em `/app/packages/backend`. Sem `WORKDIR /app` antes do `USER node`,
   o CMD `node packages/backend` tenta carregar `/app/packages/backend/packages/backend` e falha
   com `MODULE_NOT_FOUND`.

5. **`weed shell` não tem flag `-run`.** Comandos avulsos devem ser enviados via stdin:
   `echo "fs.mkdir /buckets/..." | weed shell -master=... -filer=...`.

6. **OTel via env vars padrão.** `@backstage/backend-defaults` lê `OTEL_EXPORTER_OTLP_ENDPOINT`,
   `OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_SERVICE_NAME`, `OTEL_TRACES_SAMPLER` sem nenhuma
   configuração de código adicional.

7. **Kong OSS DB-less não suporta validação JWKS dinâmica.** O plugin `openid-connect`
   é Enterprise. Em OSS DB-less, a opção viável seria Traefik ForwardAuth middleware apontando
   para um serviço de validação JWT dedicado.

---

# Business Findings

- O Backstage pode operar como IDP real no stack local com autenticação corporativa (OIDC)
  sem modificar o código-fonte — apenas configuração e um Dockerfile de patching.
- TechDocs com S3 remoto está funcionando, viabilizando documentação técnica persistida
  além do ciclo de vida do container.
- A ausência de Kong JWT OSS não bloqueia o valor do EXP-003: o risco de API não protegida
  é aceitável em ambiente local de desenvolvimento.

---

# Architecture Impact

- **Substituição de npm por yarn no Dockerfile** — decisão definitiva para qualquer imagem
  Backstage custom neste repositório.
- **Padrão `host-gateway`** — qualquer container que precise resolver `*.spire.localhost`
  via Traefik (não via DNS interno) deve usar `extra_hosts: host-gateway`.
- **Kong JWT exige alternativa** — Kong Enterprise ou Traefik ForwardAuth para validação
  de tokens Keycloak em API Gateway. Documentado como EXP-005 candidate.

---

# Reliability Impact

- Stack de 11 serviços com healthchecks em todos os componentes críticos.
- Backstage depende de Keycloak (OIDC) e SeaweedFS S3 via `depends_on: condition: service_healthy`.
- OTel Collector sem healthcheck (sem porta HTTP de health exposta por padrão) — impacto
  baixo pois Backstage não falha se OTel indisponível.

---

# Artifacts Updated

- `iac/environments/local/backstage/Dockerfile`
- `iac/environments/local/backstage/patches/index.cjs.js`
- `iac/environments/local/backstage/app-config.local.yaml`
- `iac/environments/local/seaweedfs/s3-config.json`
- `iac/environments/local/docker-compose.yml`
- `iac/environments/local/.env.example`
- `iac/environments/local/Makefile`
- `prodops/artifacts/experiments/002-local-stack/upstream-trail.md`
- `prodops/artifacts/experiments/003-backstage-integrado/experiment.md`
- `prodops/artifacts/experiments/003-backstage-integrado/upstream-trail.md`

---

# Knowledge Gaps Closed

| Pergunta | Status | Evidência |
|---|---|---|
| Build sem nunjitsu via npm? | ✅ Yarn 4 funciona; npm inviável | `yarn add` no subworkspace passa sem quarantine |
| OIDC Keycloak ↔ Backstage? | ✅ Funciona com host-gateway | `302 → keycloak.spire.localhost` sem `:8080` |
| TechDocs → SeaweedFS S3? | ✅ Conectado e pronto | `Successfully connected to the AWS S3 bucket spire-artifacts` |
| OTel traces do Backstage? | ✅ Collector recebe | `POST /v1/traces → 200` |
| Kong JWT OSS alternativa? | ❌ Não viável em DB-less | Plugin `openid-connect` é Enterprise; alternativa: Traefik ForwardAuth |

---

# New Backlog Items

- **EXP-004** — Vault integrado: secrets management central (Keycloak OIDC, PostgreSQL dinâmico, KV v2, PKI) ✅
- **EXP-005** — Kong + Keycloak OIDC + OPA: autorização no API Gateway via oidcify + kong-opafy + Rego
- **EXP-006** — Plugins Spire de negócio (OBC/OpenAPI/AsyncAPI) no Backstage
- **EXP-007 (candidate)** — OCI: migração do stack local para Oracle Cloud
- Catalog populado com entidades reais do repositório Spire
- TechDocs geração end-to-end (mkdocs-material container no SeaweedFS)

---

# Recommendation

**Adotar a estratégia de patching da imagem oficial** como padrão para builds Backstage no
Spire. A abordagem é estável, reproduzível e não requer manutenção do ciclo de build completo
do Backstage (que é lento e sujeito a breaking changes de Yarn 4).

Kong JWT foi resolvido no EXP-005 via plugins OSS: `oidcify` (OIDC/JWT) + `kong-opafy` (OPA)
— sem Kong Enterprise, sem Traefik ForwardAuth.

---

# Decision Package

| Decisão | Escolha | Racional |
|---|---|---|
| Tool para install de plugins | `yarn add` (Yarn 4) | npm incompatível com workspace `link:` do Backstage |
| Resolução de hostname Keycloak | `extra_hosts: host-gateway` | `KC_HOSTNAME_URL` não afeta backchannel interno |
| Publisher TechDocs | `awsS3` com endpoint SeaweedFS | Apache 2.0; AWS SDK suporta custom endpoint |
| OTel configuração | Env vars padrão OTEL_* | Zero código; lido por `@backstage/backend-defaults` |
| Kong JWT local | Out of scope — Enterprise ou alternativa | Plugin `openid-connect` não disponível em OSS |

---

# Exit Criteria

- [x] Hipótese original respondida
- [x] Perguntas classificadas
- [x] Lacunas de conhecimento documentadas
- [x] Impacto arquitetural documentado
- [x] Impacto em confiabilidade documentado
- [x] Artefatos atualizados
- [x] Recomendação produzida
- [x] Decision Package completo
