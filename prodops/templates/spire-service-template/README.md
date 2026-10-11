# spire-service-template

Template de repositório ProdOps para registrar serviços no Spire em < 30 minutos.

## Como usar

### 1. Crie seu repositório a partir deste template

```bash
# Via GitHub: Use este repo como template
# ou clone e adapte:
git clone https://github.com/produtoreativo/spire-service-template my-service
cd my-service
```

### 2. Configure o catalog-info.yaml

Edite `catalog-info.yaml` com os dados do seu serviço:
- `metadata.name` — slug do serviço (sem espaços)
- `metadata.title` — nome legível
- `metadata.description` — uma linha descrevendo o propósito de negócio
- `spec.owner` — time responsável (ex: `group:my-team`)

### 3. Preencha o OBC

Edite `prodops/artifacts/obcs/service-obc.md`:
- **Business Outcome**: O que este serviço entrega em valor de negócio
- **Observable Events**: Eventos verificáveis que o serviço emite
- **Initial SLIs**: O que você mede (disponibilidade, latência, erros)
- **Reliability Rules**: Os thresholds que você se compromete a manter
- **Response Contract**: Comportamento garantido por cenário

### 4. Adicione seu spec de API (opcional)

Se o serviço tem uma API HTTP/REST, adicione `api/openapi.yaml`.
Se tem canais async (Kafka, SNS, etc.), adicione `api/asyncapi.yaml`.

### 5. Configure as variáveis do repositório

No GitHub → Settings → Secrets and variables:

| Variável | Tipo | Valor |
|---|---|---|
| `SPIRE_URL` | Variable | URL da instância Spire |
| `KEYCLOAK_URL` | Variable | URL do Keycloak |
| `SPIRE_CLIENT_ID` | Variable | Client ID do pipeline |
| `SPIRE_CLIENT_SECRET` | Secret | Client secret do pipeline |

### 6. Faça push para `main`

O GitHub Action é acionado automaticamente e submete os artefatos para o Spire.
O relatório de governança aparece no log do workflow.

---

## Estrutura do repositório

```
catalog-info.yaml               ← Entidade Backstage (obrigatório)
api/
  openapi.yaml                  ← Spec OpenAPI 3.0 (opcional)
  asyncapi.yaml                 ← Spec AsyncAPI (opcional)
prodops/
  artifacts/
    obcs/
      service-obc.md            ← Observable Business Contract (obrigatório)
slo.yaml                        ← OpenSLO (opcional, advisory)
.github/
  workflows/
    spire-submit.yml            ← Workflow automático de submissão
```

## Níveis de governança

| Nível | Critério |
|---|---|
| `registered` | catalog-info.yaml submetido |
| `governed` | catalog-info + OBC válido |
| `governed+spec` | governed + OpenAPI/AsyncAPI válido + rota no Kong/Microcks |
| `governed_with_warnings` | governed mas com campos recomendados ausentes |

## Suporte

- [Documentação do Spire](https://github.com/produtoreativo/spire)
- [Guia de OBC](https://github.com/produtoreativo/spire/blob/main/prodops/artifacts/product/service-model.md)
