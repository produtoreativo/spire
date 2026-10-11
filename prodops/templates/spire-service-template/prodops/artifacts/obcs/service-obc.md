---
version: 1.0.0
status: active
changelog: |
  1.0.0: Initial OBC — service launch
---

# OBC: My Service

## Business Outcome

<!-- Required: What business outcome does this service enable?
     Write in terms of business value, not technical behavior.
     Example: "Customers complete checkout in under 3 clicks with >99.5% success rate." -->

My Service enables [BUSINESS_OUTCOME].

## Observable Events

<!-- Required: List the observable events this service emits.
     These events must be verifiable (logs, metrics, or async messages).
     At minimum include obc.validated. -->

| Event | Trigger | Observable via |
|---|---|---|
| `service.started` | Service process starts | Application logs |
| `obc.validated` | Spire validates this OBC | Spire catalog |
| `request.processed` | Request completes | Metrics / logs |

## Initial SLIs

<!-- Required: Define the Service Level Indicators (what you measure).
     These become the basis for SLOs in production. -->

| SLI | Description | Measurement |
|---|---|---|
| Availability | % of time service responds | HTTP 2xx / total requests |
| Latency p99 | 99th percentile response time | Request duration histogram |
| Error rate | % of 5xx responses | Error counter / total requests |

## Reliability Rules

<!-- Required: Define the reliability expectations (thresholds + behavior under failure).
     These are the commitments made to consumers. -->

- **Availability**: ≥ 99.5% measured over 30 days
- **Latency p99**: ≤ 500ms for all endpoints
- **Error rate**: < 0.5% under normal load
- **Graceful degradation**: Returns cached response if upstream unavailable
- **Retry policy**: Exponential backoff, max 3 retries, 1s initial delay

## Response Contract

<!-- Required: Define the response behavior for key scenarios.
     Describes what consumers can rely on. -->

| Scenario | Expected Response |
|---|---|
| Valid request | 200 OK with response body as documented in OpenAPI spec |
| Invalid input | 400 Bad Request with `{ "error": "...", "field": "..." }` |
| Not found | 404 Not Found with `{ "error": "resource not found" }` |
| Unauthorized | 401 Unauthorized |
| Service unavailable | 503 with `Retry-After` header |
