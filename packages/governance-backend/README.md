# @spire/backstage-plugin-governance-backend

Backstage backend plugin for the Spire Governance Platform.

Validates and registers service artifacts (OBCs, OpenAPI, AsyncAPI, SLO) server-side,
syncs versioned routes to Kong, and registers specs in Apicurio Registry.

## Architecture

This plugin is a first-class TypeScript package in the Spire monorepo.
It is compiled during the Backstage Docker image build and loaded as a backend plugin.

```
packages/governance-backend/
  src/
    index.ts                  ← createBackendPlugin entry point
    router.ts                 ← Express router: POST /submit, GET /health, GET /services
    detect.ts                 ← Artifact presence detection + slugify
    report.ts                 ← JSON report builder + status derivation
    types.ts                  ← Shared TypeScript interfaces
    validators/
      catalog.ts              ← catalog-info.yaml field validation
      obc.ts                  ← OBC frontmatter + section validation
      openapi.ts              ← Spectral lint + oasdiff (via CLI binaries)
      asyncapi.ts             ← asyncapi/cli validation
      slo.ts                  ← oslo validate (advisory)
    registry/
      apicurio.ts             ← Apicurio REST v3: fetch + register versions
      kong.ts                 ← Kong Admin API: upsert service/route per major version
      microcks.ts             ← Microcks: upload AsyncAPI spec for mock generation
  tests/
    unit/
      validators/
        catalog.test.ts
        obc.test.ts
      detect.test.ts
      report.test.ts
    integration/
      router.test.ts
```

## Development

```bash
# Build (TypeScript → CommonJS)
npm run build

# Watch mode
npm run build:watch

# Tests
npm test

# Tests with coverage
npm run test:coverage
```

## API

### `POST /api/spire-governance/submit`

Multipart form upload of service governance artifacts.

| Field | Type | Required | Description |
|---|---|---|---|
| `catalog_info` | file | Yes | `catalog-info.yaml` |
| `obcs` | files | Yes | `prodops/artifacts/obcs/*.md` |
| `openapi` | file | No | `api/openapi.yaml` — activates Spectral + oasdiff + Kong |
| `asyncapi` | file | No | `api/asyncapi.yaml` — activates asyncapi/cli + Microcks |
| `slo` | file | No | `slo.yaml` — advisory only, never blocks |
| `catalog_url` | string | No | GitHub raw URL for permanent catalog registration |

**Response:**
```json
{
  "status": "governed | governed_with_warnings | rejected",
  "service": "my-service",
  "timestamp": "2026-08-27T10:00:00Z",
  "duration_ms": 850,
  "processed": ["catalog-info.yaml", "2 OBC(s)", "openapi.yaml (Spectral)"],
  "versions": { "openapi": "2.0.0", "asyncapi": null },
  "kong_route_created": true,
  "catalog_registered": true,
  "errors": [],
  "warnings": [],
  "summary": "✓ Service governed — all checks passed."
}
```

### `GET /api/spire-governance/health`

Returns `{ "status": "ok", "plugin": "@spire/backstage-plugin-governance-backend" }`.

### `GET /api/spire-governance/services`

Lists governed artifacts from Apicurio Registry.

## External endpoint (via Kong)

```
POST https://api.spire.localhost/spire/api/governance/submit
```

Kong applies: `oidcify` (JWT validation) → `kong-opafy` (OPA authorization) →
`request-transformer` (inject static pipeline token) → Backstage plugin.
