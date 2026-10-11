# Spire — Publicação e Versionamento de APIs no Kong

**Status:** Proposta. Orienta a implementação do `@spire/backstage-plugin-governance-backend`.
**Data:** 2026-08-26

---

## Problema

Quando o Spire Governance Plugin registra um serviço, ele precisa configurar o Kong
para expor a API desse serviço de forma versionada, autenticada e validada em runtime.
O Kong precisa saber:

- Qual é o upstream do serviço (URL real do backend)?
- Qual é o path público da API (`/v2/payments`, `/v1/invoices`)?
- Qual é o schema de validação dos requests?
- Qual versão está ativa? Qual está deprecated?

---

## Modelo de Entidades no Kong

```
┌──────────────────────────────────────────────────────────────────┐
│  Kong Entity Model (por serviço versionado)                      │
│                                                                  │
│  Service: payments-api-v2                                        │
│    url: https://lambda-url.us-east-1.amazonaws.com/v2           │
│    tags: [spire, service:payments-api, version:v2, active]      │
│                                                                  │
│  Route: payments-api-v2-route                                    │
│    paths: [/v2/payments]                                         │
│    service: payments-api-v2                                      │
│    tags: [spire, service:payments-api, version:v2, active]      │
│                                                                  │
│  Plugins (na Route):                                             │
│    oidcify           → valida JWT Keycloak                      │
│    kong-opafy        → OPA authz                                │
│    request-validator → schema extraído do openapi.yaml          │
│    response-transformer → (se deprecated) header Deprecation:   │
└──────────────────────────────────────────────────────────────────┘
```

### Por que tags estruturadas?

Tags permitem gerenciar o lifecycle por serviço sem impactar outras rotas:

| Tag | Uso |
|---|---|
| `spire` | Identifica entidades gerenciadas pelo Spire (não editar manualmente) |
| `service:{name}` | Filtra todas as versões de um serviço |
| `version:v{N}` | Filtra uma versão específica |
| `active` | Versão em produção — recebe tráfego normal |
| `deprecated` | Versão mantida mas com aviso de sunset |
| `sunset:{date}` | Data de remoção planejada |

Exemplos de consulta via Kong Admin API:

```bash
# todas as rotas de payments-api
GET /routes?tags=service:payments-api

# todas as versões deprecated em qualquer serviço
GET /services?tags=spire,deprecated

# remover version v1 inteira
DELETE /services?tags=service:payments-api,version:v1
```

---

## Como o Plugin Deriva a Configuração

O plugin lê o `openapi.yaml` submetido e extrai automaticamente:

```
openapi.yaml                    Kong entity
───────────────────────────────────────────────────────────────
info.title (kebab)         →  service slug  (payments-api)
info.version (semver)      →  major version (v2.1.0 → v2)
servers[0].url             →  Service.url   (upstream backend)
paths.*                    →  Route.paths   (/v2/{slug}/{path})
paths.*.requestBody.schema →  request-validator.body_schema
```

**Exemplo de derivação:**

```yaml
# openapi.yaml submetido
info:
  title: Payments API
  version: 2.1.0
servers:
  - url: https://lambda-url.us-east-1.amazonaws.com
paths:
  /invoices:
    post:
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateInvoiceRequest'
```

```typescript
// Plugin deriva:
const slug = 'payments-api'                     // de info.title
const major = 2                                 // de info.version
const upstream = 'https://lambda-url...'        // de servers[0].url
const routePath = `/v${major}/${slug}`          // /v2/payments-api
const kongServiceName = `${slug}-v${major}`     // payments-api-v2
const schema = extractSchema(spec, '/invoices', 'post', 'requestBody')
```

---

## Fluxo de Publicação pelo Plugin

```
Plugin recebe: openapi.yaml v2.1.0 + catalog-info.yaml

1. Derivar slug, major, upstream, route path, schema

2. Verificar estado no Kong (via Admin API)
   GET /services/payments-api-v2

   a. 404 → nova major version → criar Service + Route + Plugins
   b. 200 → mesma major version → atualizar apenas request-validator schema

3. Upsert Service
   PUT /services/payments-api-v2
   { url, tags: [spire, service:payments-api, version:v2, active] }

4. Upsert Route
   PUT /routes/payments-api-v2-route
   { paths: [/v2/payments-api], service: payments-api-v2, tags: [...] }

5. Upsert Plugins na Route
   - oidcify (auth)
   - kong-opafy (OPA authz)
   - request-validator (schema derivado do openapi.yaml)

6. Se há versão anterior (v1) ainda ativa:
   → adiciona response-transformer em payments-api-v1-route
     com header: Deprecation: true, Sunset: <data configurada>
   → atualiza tag: active → deprecated
```

---

## Versionamento no Kong: o que muda por tipo de change

| Tipo de change | Detectado por | Ação no Kong |
|---|---|---|
| PATCH (1.0.0 → 1.0.1) | oasdiff: sem breaking | Atualiza só request-validator schema na route v1 |
| MINOR (1.0.0 → 1.1.0) | oasdiff: non-breaking | Atualiza request-validator schema; adiciona novos paths se houver |
| MAJOR (1.x → 2.0.0) | oasdiff: breaking | Cria Service `v2` + Route `/v2/...` + Plugins novos; `v1` recebe tag `deprecated` |

**Invariante:** versões antigas nunca são deletadas automaticamente pelo Spire.
Deleção é explícita via endpoint de sunset.

---

## API de Gerenciamento (Governance Plugin)

O plugin expõe endpoints de gestão do lifecycle de versões:

```
POST   /api/spire-governance/submit
       Submete artefatos → processa → publica no Kong + Backstage

GET    /api/spire-governance/services
       Lista todos os serviços governados com suas versões ativas

GET    /api/spire-governance/services/{slug}/versions
       Lista versões de um serviço com status (active/deprecated/sunset)

POST   /api/spire-governance/services/{slug}/versions/{version}/deprecate
       Marca versão como deprecated; configura Sunset header no Kong

DELETE /api/spire-governance/services/{slug}/versions/{version}
       Remove route e service do Kong (somente versões deprecated)
```

---

## OPA: Autorização por Versão de API

As regras do OPA precisam cobrir rotas versionadas de serviços governados:

```rego
# ─── serviços governados pelo Spire ───────────────────────────────
# qualquer consumidor autenticado pode chamar APIs publicadas
allow if {
    regex.match(`^/v[0-9]+/[a-z][a-z0-9-]*/`, input.path)
    input.method in {"GET", "POST", "PUT", "DELETE", "PATCH"}
    count(roles) > 0  # qualquer role válida — autenticado = autorizado
}

# consumidores com role específica podem acessar APIs restritas
allow if {
    "payments-consumer" in roles
    startswith(input.path, "/v2/payments-api/")
}
```

---

## Backstage: Catalog-info para Rotas Kong

O `catalog-info.yaml` ganha annotations que o plugin usa para enriquecer o catalog:

```yaml
metadata:
  annotations:
    spire.io/kong-route: /v2/payments-api
    spire.io/api-version: v2.1.0
    spire.io/api-status: active          # active | deprecated | sunset
    spire.io/apicurio-artifact-id: payments-api
    spire.io/apicurio-group: spire
```

O Backstage API entity fica assim no catalog:

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: payments-api-v2
  annotations:
    spire.io/kong-route: /v2/payments-api
    spire.io/api-status: active
spec:
  type: openapi
  lifecycle: production
  owner: group:default/team-payments
  system: spire
  definition:
    $text: https://apicurio.spire.local/groups/spire/artifacts/payments-api/versions/2.1.0
```

---

## Diagrama: Lifecycle de Versão

```
openapi v1.0.0 submetido
    → Kong: /v1/payments-api (active)
    → Apicurio: payments-api@1.0.0
    → Backstage: API entity payments-api-v1 (lifecycle: production)

openapi v1.2.0 submetido (minor — non-breaking)
    → Kong: /v1/payments-api (active) — request-validator schema atualizado
    → Apicurio: payments-api@1.2.0
    → Backstage: API entity payments-api-v1 atualizado

openapi v2.0.0 submetido (major — breaking)
    → Kong: /v2/payments-api (active) — nova route criada
    → Kong: /v1/payments-api (deprecated) — Deprecation header adicionado
    → Apicurio: payments-api@2.0.0
    → Backstage: API entity payments-api-v2 criado, v1 marcado deprecated

POST /deprecate v1 + sunset: 2026-12-31
    → Kong: /v1/payments-api — Sunset: 2026-12-31 header adicionado
    → Backstage: payments-api-v1 lifecycle: deprecated

DELETE v1 (pós sunset)
    → Kong: payments-api-v1 service + route removidos
    → Backstage: payments-api-v1 lifecycle: withdrawn
```

---

## Referências

- [overview.md](overview.md) — ADR-009 (Backstage plugin), ADR-008 (request-validator)
- [api-validation-strategy.md](api-validation-strategy.md) — Spectral, oasdiff, Apicurio
- [diagram.md](diagram.md) — diagramas de componente e sequência
