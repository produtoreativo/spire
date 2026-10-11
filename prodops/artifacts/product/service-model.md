# Spire — Service Model

## Os três tipos de deck

### Product Deck

Descreve um **produto digital** com múltiplos serviços e valor de negócio claro.

Contém:
- Visão, posicionamento e personas
- OBC Global (contrato observável do produto como um todo)
- Mapa de serviços e value streams
- Roadmap orientado a business outcomes

### Platform Deck

Descreve uma **plataforma shared** que outros serviços consomem como infraestrutura
ou capacidade interna.

Contém:
- Visão de plataforma e personas (consumidores internos)
- SLOs de plataforma como contratos explícitos com consumidores
- Modelo de adoção, onboarding e suporte

### Service Deck

Descreve um **serviço individual** dentro de um produto ou plataforma.

**Obrigatório:**
- `catalog-info.yaml` — identidade, ownership e dependências no Backstage
- `prodops/artifacts/obcs/*.md` — ≥ 1 OBC por capability do serviço

**Opcional — conforme o tipo de interface do serviço:**
- `api/openapi.yaml` — serviços com interface HTTP/REST síncrona
- `api/asyncapi.yaml` — serviços com interface assíncrona (Kafka, AMQP, WebSocket)

Um serviço pode ter apenas OpenAPI, apenas AsyncAPI, ambos, ou nenhum dos dois.
O que determina o nível de governança é o OBC — não a presença de spec de API.

---

## O OBC (Observable Business Contract)

```
OBC =
  Business Outcome         — o que o serviço promete entregar para o negócio
  + Observable Events      — o evento que prova que o outcome ocorreu
  + Initial SLIs           — como medir (métricas iniciais)
  + Reliability Rules      — quando é confiável o suficiente para produção
  + Response Contract      — o que o serviço promete retornar (schema/exemplo)
```

Um serviço é **governado** quando tem ≥ 1 OBC com todas as cinco seções e
passou pela pipeline de submissão do Spire sem erros críticos.

Um OBC com seções faltando gera **warning** (não bloqueia registro) mas
fica marcado como incompleto no catalog.

---

## Hierarquia de artefatos

```
Spire (Platform Deck — este repositório)
├── prodops/artifacts/product/
│   ├── product-vision.md      — visão, posicionamento, personas
│   ├── global-obc.md          — contrato observável do Spire como produto
│   ├── service-model.md       — este arquivo
│   ├── target-personas.md     — personas detalhadas
│   └── roadmap.md             — roadmap orientado a outcomes
│
└── [Serviços governados — repositórios externos]
    ├── catalog-info.yaml       — identidade Backstage (kind: Component)
    ├── api/openapi.yaml        — spec técnica pública
    └── prodops/artifacts/obcs/
        └── <capability>.md    — OBC por capability
```

---

## Pipeline de submissão

Qualquer serviço pode ser governado pelo Spire rodando `spire-submit.sh`
(referência: `produtoreativo/payments-api`).

O script executa em ordem:

```
1. Validação local
   ├── catalog-info.yaml  → campos obrigatórios + spec.system: spire
   ├── api/openapi.yaml   → versão 3.x, info.title, paths não vazio
   └── prodops/obcs/*.md  → seções Business Outcome + Observable Events

2. Autenticação
   └── Keycloak client_credentials → JWT (aud: kong, role: spire-registrar)

3. Submissão
   └── POST /backstage/api/catalog/locations
       → Kong (oidcify + OPA) → Backstage catalog API
       → 201 (novo) | 409 (já existe — refresh automático)

4. Relatório
   └── JSON com status, erros, warnings e artifacts detectados
```

---

## Critério de governança

| Nível | Condição | Status no catalog |
|---|---|---|
| **Governado** | catalog-info + ≥1 OBC completo | `governed` |
| **Governado com spec** | catalog-info + ≥1 OBC completo + OpenAPI e/ou AsyncAPI válidos | `governed` + spec publicada no Kong / Microcks |
| **Parcial** | catalog-info + ≥1 OBC com warnings | `partial` |
| **Registrado** | catalog-info apenas | `registered` |
| **Não registrado** | Ausente do Spire | — |

**Regra:** a spec de API (OpenAPI ou AsyncAPI) é **opcional** e não bloqueia o nível
`governed`. O que diferencia é a presença de spec válida — que habilita publicação no
Kong (OpenAPI) ou Microcks (AsyncAPI) e validação em runtime.
