# OBC Global — Spire Platform

## Status

Upstream. OBC de produto — contrato observável do Spire como plataforma de governança.

---

## Business Outcome

Engenheiros de plataforma e tech leads podem registrar seus serviços no Spire com
contratos observáveis válidos, tornando a conformidade de governança de arquitetura
verificável e rastreável de forma automática — sem revisão manual, sem overhead
de processo.

---

## Observable Events

| Evento | Quando ocorre | Produtor |
|---|---|---|
| `service.registered` | Um serviço passou pela pipeline com catalog-info.yaml válido | spire-submit.sh |
| `obc.validated` | ≥ 1 OBC do serviço passou validação de seções obrigatórias | spire-submit.sh |
| `service.catalog.updated` | O serviço está visível como Component no Backstage catalog | Backstage |
| `spec.published` | A spec OpenAPI do serviço está publicada e referenciada | Backstage |
| `obc.warning` | OBC submetido com seções recomendadas faltando | spire-submit.sh |
| `submission.rejected` | Pipeline bloqueada por erro crítico de validação | spire-submit.sh |

---

## Initial SLIs

| SLI | Meta | Método de Medição |
|---|---|---|
| Serviços com `obc.validated` | Crescimento monotônico (não decresce) | COUNT de services com ≥1 OBC completo no catalog |
| Taxa de sucesso de submissão | ≥ 95% | HTTP 201 + 409 / total de chamadas à pipeline |
| Tempo de registro ponta a ponta | < 5 min | t(`service.registered`) − t(início do script) |
| Disponibilidade da pipeline | ≥ 99,5% horário comercial (08h–20h BRT) | Health check do endpoint POST /backstage/api/catalog/locations |

---

## Reliability Rules

- A pipeline de submissão (POST /backstage/api/catalog/locations) deve estar disponível
  99,5% do tempo nos horários de trabalho (08h–20h BRT)
- O Backstage catalog deve processar um novo location em < 60s após registro
- Erros de validação de OBC devem ser humano-legíveis e conter o campo exato com problema
- Erros de autenticação (401/403) devem retornar mensagem clara sobre a role necessária
- A submissão deve ser **idempotente**: registrar o mesmo serviço duas vezes retorna 409,
  não duplicata

---

## Response Contract

```json
// 201 Created — novo serviço registrado com sucesso
{
  "location": {
    "id": "<uuid>",
    "type": "url",
    "target": "<github-raw-url-de-catalog-info.yaml>",
    "entityRef": "location:default/<nome-do-serviço>"
  },
  "entities": []
}

// 409 Conflict — serviço já registrado (idempotente)
// Backstage agenda re-fetch automático do catalog-info.yaml

// Validation Report (spire-submit.sh)
{
  "service": "<nome-do-serviço>",
  "timestamp": "<ISO8601>",
  "status": "valid | warnings | invalid",
  "summary": {
    "errors": 0,
    "warnings": 2
  },
  "artifacts": {
    "catalog": "catalog-info.yaml",
    "openapi": "api/openapi.yaml",
    "obcs_dir": "prodops/artifacts/obcs"
  }
}
```

**Códigos de erro:**
- `401 Unauthorized` — JWT ausente ou inválido
- `403 Forbidden` — JWT válido mas sem role `spire-registrar`
- `validation.error` — catalog-info.yaml, openapi.yaml ou OBC com erro crítico (bloqueia submissão)
- `validation.warning` — OBC com seções recomendadas faltando (não bloqueia)
