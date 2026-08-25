# Spire — IaC

Infraestrutura como código para o Spire Platform.

## Ambientes

| Ambiente | Localização | Descrição |
|---|---|---|
| `local` | `environments/local/` | Docker Compose — dev e validação local |
| `reference` | `environments/reference/` | OCI Free Tier — instância de referência (em construção) |

## Início rápido — Local

```bash
cd environments/local
make up
```

Serviços disponíveis após `make up`:

| Serviço | URL |
|---|---|
| Backstage | http://backstage.spire.localhost |
| Keycloak | http://keycloak.spire.localhost |
| Kong Admin | http://kong-admin.spire.localhost |
| MinIO Console | http://minio.spire.localhost |
| Traefik Dashboard | http://localhost:8080 |

Adicione ao `/etc/hosts`:
```
127.0.0.1 backstage.spire.localhost keycloak.spire.localhost
127.0.0.1 kong-admin.spire.localhost api.spire.localhost
127.0.0.1 minio.spire.localhost artifacts.spire.localhost
```

## Estrutura

```
iac/
├── environments/
│   ├── local/              # Docker Compose
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   ├── Makefile
│   │   ├── keycloak/       # realm-spire.json
│   │   ├── kong/           # kong.yml (declarative)
│   │   ├── postgres/       # init scripts
│   │   ├── traefik/        # dynamic config
│   │   └── otel/           # collector config
│   └── reference/          # OpenTofu — OCI Free Tier (em construção)
│       ├── main.tf
│       └── modules/
└── README.md
```

## Stack

- **Traefik** — ingress / reverse proxy
- **Backstage** — IDP (portal + catálogo OBC)
- **Keycloak** — IdP OIDC / OAuth2
- **Kong OSS** — API Gateway
- **PostgreSQL** — banco de dados compartilhado
- **Redis** — cache de sessão
- **MinIO** — object storage local (S3-compat; OCI Object Storage em produção)
- **OTEL Collector** — coleta de traces e métricas
