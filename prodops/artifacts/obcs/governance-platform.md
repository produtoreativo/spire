---
version: 0.1.0
status: active
changelog: |
  0.1.0: Initial OBC — governance submission and service registration
---

# OBC: Spire Governance Platform

## Business Outcome

Engineering teams submit service artifacts to Spire and receive a governance report
in under 60 seconds, enabling time-to-governance < 30 minutes from first commit.

## Observable Events

| Event | Trigger | Observable via |
|---|---|---|
| `obc.validated` | Service submits artifacts via `/spire/api/governance/submit` | Spire governance report |
| `catalog.registered` | `catalog-info.yaml` registered in Backstage catalog | Backstage Software Catalog |
| `schema.registered` | OpenAPI spec version registered in Apicurio Registry | Apicurio Registry UI |
| `kong.route.upserted` | Kong route created or updated for the service | Kong Admin API |

## Initial SLIs

| SLI | Description | Target |
|---|---|---|
| Submission latency | Time from POST to governance report returned | p95 < 10s |
| Availability | % submissions that complete without 5xx | >= 99% |
| Governance acceptance rate | % submissions that result in `governed` or `governed_with_warnings` | >= 95% |

## Reliability Rules

- Submission endpoint must return a structured JSON report even on validation failure (never raw 500)
- If Apicurio Registry is unavailable, submission must still complete with a warning (non-blocking)
- If Kong Admin API is unavailable, submission must still complete with a warning (non-blocking)
- JWT validation failure must return 401 before processing any artifacts

## Response Contract

| Scenario | HTTP Status | Response Shape |
|---|---|---|
| Governed | 200 | `{"status": "governed", ...}` |
| Governed with warnings | 200 | `{"status": "governed_with_warnings", ...}` |
| Rejected (validation errors) | 200 | `{"status": "rejected", "errors": [...]}` |
| Auth failure | 401 | Keycloak/Kong error |
| Malformed request | 400 | `{"error": "..."}` |
