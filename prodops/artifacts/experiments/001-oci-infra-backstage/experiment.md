# EXP-001 — IaC OCI Free Tier + Backstage FOSS Stack

## Status

- [ ] Planned
- [x] In Progress
- [ ] Completed
- [ ] Cancelled

**Iniciado em:** 2026-08-25
**Operador:** Christiano Milfont

---

# Business Goal

Definir e validar a arquitetura de infraestrutura do Spire rodando 100% em Oracle Cloud
Infrastructure (OCI) Free Tier, usando exclusivamente componentes FOSS.

O Spire precisa de um ambiente de referência que qualquer equipe possa replicar sem custo
para hospedar, versionar e validar artefatos de produto (OBC, OpenAPI, OpenSLO, AsyncAPI,
CloudEvents, OpenTelemetry, OPA) integrados ao IDP Backstage.

**Resultado esperado:** IaC completo (OpenTofu + Helm + K3s) que instala o ambiente Spire
em uma conta OCI Free Tier do zero, com retrocompatibilidade garantida para updates de
Backstage.

---

# Repository Scope Gate

**Decisão:** ✅ Prosseguir — este repositório É o Spire. Toda infraestrutura, plugins e
IaC são de responsabilidade direta deste repo.

---

# Questions to Answer

1. Quais recursos OCI Free Tier estão disponíveis e são suficientes para rodar o stack?
2. Qual a composição mínima do stack FOSS (Backstage, Keycloak, Kong, DB, etc.)?
3. Como estruturar o IaC com OpenTofu para OCI?
4. Como garantir retrocompatibilidade de plugins Backstage em versões futuras?
5. Como o Spire valida cada tipo de spec (OpenAPI, OpenSLO, AsyncAPI, CloudEvents, OTel, OPA)?
6. Como os artefatos OBC são versionados e publicados pelo Backstage?
7. K3s ou K8s nativo do OKE para orquestração dos serviços?

---

# Hypothesis

**H1:** Os recursos ARM Ampere A1 do OCI Free Tier (4 OCPUs, 24 GB RAM) são suficientes
para rodar um K3s com Backstage + Keycloak + Kong + PostgreSQL + armazenamento de artefatos.

**H2:** O modelo de plugins Backstage (Entity Providers + Catalog Backend Modules) é o vetor
correto para integrar validação de specs sem quebrar versões futuras do Backstage.

**H3:** A arquitetura spec-agnostic (plugável por tipo de spec) permite adicionar novos
formatos públicos sem reescrever o núcleo do Spire.

---

# Scope

- Mapeamento completo dos recursos OCI Free Tier (Always Free)
- Definição do stack FOSS e sizing de cada componente
- Arquitetura de rede OCI (VCN, subnets, Security Lists, Load Balancer)
- Estratégia de IaC: módulos OpenTofu para OCI
- Estratégia de bootstrap K3s em ARM Ampere
- Camada de identidade: Keycloak como IdP + OAuth2 Proxy para Backstage
- API Gateway: Kong OSS como proxy e validação de specs em runtime
- Estratégia de armazenamento de artefatos (OBC, specs)
- Mapeamento de validadores FOSS por tipo de spec
- Estratégia de retrocompatibilidade de plugins Backstage

---

# Out of Scope

- Implementação dos plugins Backstage (experimento posterior)
- CI/CD pipeline (experimento posterior)
- Produção multi-tenant (este experimento cobre apenas instância de referência)
- Integração com provedores de spec externos (ex: Apicurio, SchemaRegistry comercial)
- Monitoramento completo (Prometheus/Grafana definidos mas não configurados em detalhe)

---

# OCI Free Tier — Recursos Disponíveis

## Always Free (permanentes)

| Recurso | Limite | Observações |
|---|---|---|
| **Compute ARM (Ampere A1)** | 4 OCPUs + 24 GB RAM (total) | Pode dividir em 1–4 instâncias |
| **Compute AMD** | 2 VMs × (1 OCPU + 1 GB RAM) | Muito limitado — não usar para workloads |
| **Block Volume** | 200 GB total | Boot + data volumes |
| **Object Storage** | 20 GB | Artefatos OBC, specs |
| **Load Balancer** | 1 × 10 Mbps flexível | Entrada pública |
| **VCN** | 2 VCNs | Redes virtuais |
| **Outbound Transfer** | 10 TB/mês | Suficiente para uso interno |
| **DNS** | 1 zona DNS pública | |
| **OKE (Kubernetes)** | Control plane grátis | Nós pagos — usar K3s no ARM |
| **Vault** | 20 keys + 150 secret versions | Secrets management |
| **Notifications** | 1M/mês | |
| **Monitoring** | 500M data points ingested | |

## Alocação de Instâncias ARM Proposta

| VM | OCPUs | RAM | Papel |
|---|---|---|---|
| `spire-node-1` (control plane) | 2 | 12 GB | K3s server + etcd |
| `spire-node-2` (worker) | 2 | 12 GB | K3s agent — workloads |

> Alternativa single-node: 4 OCPUs + 24 GB tudo em uma VM (mais simples, sem HA).
> Recomendação para referência: **single-node** até ter workloads que justifiquem HA.

---

# Stack FOSS — Composição e Sizing

## Componentes

| Componente | Versão | Papel | RAM estimada | CPU estimada |
|---|---|---|---|---|
| **K3s** | v1.30+ | Orquestrador leve | ~512 MB | 0.5 OCPU |
| **Backstage** | latest (node LTS) | IDP — catálogo, portal | ~768 MB | 0.5 OCPU |
| **Keycloak** | 25+ (Quarkus) | IdP — OIDC/OAuth2/SSO | ~512 MB | 0.5 OCPU |
| **Kong OSS** | 3.x | API Gateway + validação runtime | ~256 MB | 0.25 OCPU |
| **PostgreSQL** | 16 | DB de Backstage + Keycloak + Kong | ~256 MB | 0.25 OCPU |
| **Redis** | 7 | Cache de sessão / rate limit | ~128 MB | 0.1 OCPU |
| **MinIO** | latest | Object storage S3-compat (artefatos OBC) | ~256 MB | 0.25 OCPU |
| **Nginx Ingress** | latest | Ingress K3s | ~64 MB | 0.1 OCPU |
| **cert-manager** | latest | TLS automático (Let's Encrypt) | ~64 MB | 0.1 OCPU |
| **OAuth2 Proxy** | latest | Auth proxy para Backstage/Keycloak | ~32 MB | 0.05 OCPU |
| **Prometheus** | latest | Métricas (stack observabilidade) | ~256 MB | 0.25 OCPU |
| **Grafana** | latest | Dashboards | ~256 MB | 0.25 OCPU |
| **OTEL Collector** | latest | Coleta de traces e métricas | ~128 MB | 0.1 OCPU |

**Total estimado:** ~3.5 GB RAM / ~3.25 OCPUs — ✅ cabe em 24 GB / 4 OCPUs

## Validadores de Spec por Tipo

| Spec | Validador FOSS | Integração no Spire |
|---|---|---|
| **OpenAPI 3.x** | [Spectral](https://github.com/stoplightio/spectral) + [swagger-parser](https://github.com/APIDevTools/swagger-parser) | Plugin Backstage + Kong |
| **OpenSLO** | [oslo](https://github.com/openslo/oslo) | Plugin Backstage |
| **AsyncAPI** | [@asyncapi/parser](https://github.com/asyncapi/parser-js) + [asyncapi-validate](https://github.com/WaleedAshraf/asyncapi-validator) | Plugin Backstage |
| **CloudEvents** | [cloudevents/sdk-javascript](https://github.com/cloudevents/sdk-javascript) | Plugin Backstage + Kong |
| **OpenTelemetry** | [OTEL Collector](https://opentelemetry.io/docs/collector/) + semantic conventions validator | Plugin Backstage |
| **OPA** | [OPA](https://www.openpolicyagent.org/) (conftest) | Plugin Backstage + sidecar |

---

# Arquitetura OCI — Rede

```
Internet
    │
    ▼
OCI Load Balancer (10 Mbps, Free Tier)
    │  HTTPS :443
    ▼
VCN: spire-vcn (10.0.0.0/16)
    │
    ├── Public Subnet (10.0.1.0/24)
    │       └── Load Balancer NIC
    │
    └── Private Subnet (10.0.2.0/24)
            ├── spire-node-1 (ARM, K3s server)
            └── spire-node-2 (ARM, K3s agent)  [opcional — single-node alternativa]

Security Lists:
  - Ingress :443 público → LB
  - Ingress :6443 (K3s API) → restrito a IPs de gestão
  - Ingress :22 (SSH) → restrito a IPs de gestão
  - Egress: tudo permitido (Let's Encrypt, pull de imagens)
```

---

# Arquitetura de Aplicação — K3s

```
Internet → OCI LB → Nginx Ingress Controller
                        │
              ┌─────────┼──────────────┐
              ▼         ▼              ▼
          Backstage   Kong OSS    Keycloak
          (portal)   (gateway)   (IdP OIDC)
              │         │              │
              └─────────┴──────────────┘
                        │
                   PostgreSQL (shared)
                   Redis (cache)
                   MinIO (artefatos OBC/specs)
                   OTEL Collector
                   Prometheus + Grafana
```

## Fluxo de Autenticação

```
Browser → Backstage → OAuth2 Proxy → Keycloak (OIDC)
                                          │
                              Token JWT retornado
                                          │
                   Kong valida JWT via Keycloak JWKS endpoint
```

## Fluxo de Validação de Artefatos

```
Usuário publica OBC + specs (OpenAPI, AsyncAPI, etc.)
    │
    ▼
Backstage Plugin Spire (Entity Provider)
    │  lê specs do MinIO / Git
    ▼
Validator Pipeline (por tipo de spec)
    ├── OpenAPI → Spectral + swagger-parser
    ├── AsyncAPI → @asyncapi/parser
    ├── OpenSLO → oslo CLI
    ├── CloudEvents → sdk-javascript schema check
    ├── OTel → OTEL Collector dry-run
    └── OPA → conftest
    │
    ▼
Resultado: PASS / FAIL + relatório de violações
    │
    ▼
Backstage Catalog Entity atualizado com badge de validação
Kong: apenas specs PASS expostas via API Gateway
```

---

# Estratégia IaC — Terraform + Helm

**Decisão (2026-08-25):** Terraform (HashiCorp) — não OpenTofu.
Boas práticas: arquivos isolados por responsabilidade, módulos reutilizáveis,
state remoto no OCI Object Storage, tfvars por ambiente, sem secrets em VCS.

## Convenção de Arquivos por Módulo/Ambiente

Cada módulo e cada environment segue a mesma estrutura de arquivos isolados:

```
<diretório>/
├── versions.tf       # required_version e required_providers
├── providers.tf      # configuração do provider (apenas nos environments)
├── backend.tf        # state remoto (apenas nos environments)
├── variables.tf      # declaração de todas as variáveis de entrada
├── locals.tf         # valores derivados e composições internas
├── data.tf           # data sources (lookups em recursos existentes)
├── main.tf           # recursos principais ou chamadas de módulos
└── outputs.tf        # valores exportados
```

Regras:
- `main.tf` **nunca** declara variáveis, providers ou outputs — apenas recursos
- Secrets **nunca** em `.tfvars` commitados — usar `TF_VAR_*` ou OCI Vault
- Um módulo por responsabilidade de infraestrutura (network ≠ compute ≠ storage)

## Estrutura Completa

```
iac/
├── modules/                        # Módulos reutilizáveis
│   ├── oci-network/                # VCN, subnets, IGW, NAT, route tables
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   │
│   ├── oci-compute/                # Instância ARM A1, SSH key, cloud-init
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── data.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── templates/
│   │       └── cloud-init.yaml.tpl # bootstrap K3s + dependências
│   │
│   ├── oci-security/               # Security Lists e NSGs
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   │
│   ├── oci-lb/                     # Load Balancer público (Free Tier)
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── locals.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   │
│   ├── oci-storage/                # Object Storage bucket (artefatos OBC)
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   │
│   └── oci-vault/                  # OCI Vault + secrets (senhas, API keys)
│       ├── versions.tf
│       ├── variables.tf
│       ├── main.tf
│       └── outputs.tf
│
├── environments/
│   ├── reference/                  # OCI Free Tier — instância de referência
│   │   ├── versions.tf             # Fixa versão do Terraform e providers
│   │   ├── providers.tf            # Configura provider OCI + helm + kubernetes
│   │   ├── backend.tf              # State remoto no OCI Object Storage
│   │   ├── variables.tf            # Variáveis do ambiente
│   │   ├── locals.tf               # Tags comuns, nomes compostos
│   │   ├── data.tf                 # Availability Domains, imagens ARM
│   │   ├── main.tf                 # Chama módulos: network, compute, lb, storage
│   │   ├── outputs.tf              # IPs, URLs, IDs exportados
│   │   └── terraform.tfvars.example  # Template sem secrets
│   │
│   └── local/                      # Docker Compose (sem Terraform)
│       ├── docker-compose.yml
│       ├── .env.example
│       └── ...
│
├── helm/                           # Helm values por chart
│   ├── backstage/
│   │   └── values.yaml
│   ├── keycloak/
│   │   └── values.yaml
│   ├── kong/
│   │   └── values.yaml
│   ├── cert-manager/
│   │   └── values.yaml
│   └── kube-prometheus-stack/
│       └── values.yaml
│
└── scripts/
    ├── k3s-bootstrap.sh            # Instala K3s (executado via cloud-init)
    └── helm-apply.sh               # Aplica todos os charts após K3s pronto
```

## versions.tf (environment reference)

```hcl
terraform {
  required_version = "~> 1.9"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
```

## backend.tf (state remoto no OCI Object Storage)

```hcl
# O bucket de state é criado manualmente antes do primeiro terraform init.
# Nunca usar state local em ambientes compartilhados.
terraform {
  backend "s3" {
    # OCI Object Storage expõe API S3-compatível
    bucket                      = "spire-tfstate"
    key                         = "reference/terraform.tfstate"
    region                      = "us-ashburn-1"
    endpoint                    = "https://<namespace>.compat.objectstorage.us-ashburn-1.oraclecloud.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}
```

## terraform.tfvars.example

```hcl
# Copiar para terraform.tfvars — NUNCA commitar terraform.tfvars
# Secrets via TF_VAR_* ou OCI Vault

tenancy_ocid     = "ocid1.tenancy.oc1..xxxxxxxx"
user_ocid        = "ocid1.user.oc1..xxxxxxxx"
fingerprint      = "xx:xx:xx:xx"
region           = "us-ashburn-1"
compartment_ocid = "ocid1.compartment.oc1..xxxxxxxx"

# Compute
instance_shape       = "VM.Standard.A1.Flex"
instance_ocpus       = 4
instance_memory_gb   = 24
ssh_public_key_path  = "~/.ssh/spire-oci.pub"

# DNS
domain = "spire.example.com"   # substituir pelo domínio real
```

---

# Retrocompatibilidade de Plugins Backstage

## Princípio

Plugins Spire NUNCA alteram contratos internos do Backstage.
Toda extensão usa APIs públicas e estáveis do Backstage:

| API Backstage | Uso no Spire |
|---|---|
| `CatalogBuilder` + `EntityProvider` | Importa OBCs como Entities |
| `BackstagePlugin` (frontend) | UI de validação de specs |
| `createRouter` (backend plugin) | API de validação de specs |
| `AuthService`, `DatabaseService` | Integra com Keycloak e PostgreSQL |
| `ScaffolderAction` | Cria novo OBC via template |
| `SearchCollator` | Indexa specs e OBCs |

## Estratégia de Versão

- Declarar `peerDependencies` em cada plugin Backstage com intervalo amplo (`>=1.x`)
- CI testa contra: `backstage-version-matrix` (último estável + LTS anterior)
- Nenhum import de `@backstage/backend-common` deprecated (usar `@backstage/backend-plugin-api`)
- Usar `createBackendModule` (novo sistema de backend) — não `createPlugin` legado

---

# Architecture Impact

## Decisões Confirmadas

- **OpenTofu** (não Terraform): licença MPL mais permissiva, fork compatível
- **K3s** (não OKE nativo): OKE cobra pelos nós; K3s roda direto nas VMs ARM grátis
- **Single-node por padrão**: Free Tier tem 4 OCPUs/24GB — suficiente para referência
- **MinIO** (não OCI Object Storage nativo via SDK): interface S3-compat facilita portabilidade
- **Kong OSS** (não Kong Enterprise): FOSS, sem custos de licença
- **Keycloak** (não Auth0/Okta): FOSS, auto-hospedado, OIDC compliant

## Decisões Fechadas (2026-08-25)

| Decisão | Escolha | Justificativa |
|---|---|---|
| Topologia K3s | **Single-node** | Free Tier de referência; HA não é requisito inicial |
| Armazenamento OBC (OCI) | **OCI Object Storage nativo** | 20 GB grátis no Always Free; elimina MinIO na OCI |
| Armazenamento OBC (local) | **MinIO** | Substituto S3-compat para ambiente local/docker-compose |
| Ingress | **Traefik** | Já incluso no K3s — zero overhead operacional |
| DNS | **A definir pelo operador** | Operador criará domínio; usar cert-manager + Let's Encrypt |
| Backstage DB | **PostgreSQL** | SQLite não é adequado para produção |
| Spec storage | **OCI Object Storage** (OCI) / **MinIO** (local) | Consistência S3-compat entre ambientes |

---

# Technical Findings (Parciais — em progresso)

- OCI Ampere A1 é ARM64. Todos os containers precisam de imagens `linux/arm64` ou `linux/amd64`
  com emulação (mais lento). Verificar disponibilidade de imagens ARM para cada componente:
  - Backstage: ✅ (Node.js ARM64 nativo)
  - Keycloak: ✅ (Quarkus ARM64 disponível desde v21)
  - Kong OSS: ✅ (imagem oficial ARM64 disponível)
  - PostgreSQL: ✅ (ARM64 nativo)
  - MinIO: ✅ (ARM64 nativo)
  - Redis: ✅ (ARM64 nativo)
  - Prometheus/Grafana: ✅ (ARM64 disponíveis)

- OCI Free Tier requer conta com cartão de crédito mas **não cobra** pelos Always Free resources
- Limit de 2 VCNs no Free Tier — usar 1 para o Spire
- OCI Block Volume: mínimo 50 GB por volume — planejar 3 volumes: boot (50 GB) + data (100 GB) + backup (50 GB) = 200 GB total

---

# New Backlog Items

| Item | Tipo | Prioridade |
|---|---|---|
| IaC módulo `oci-network` (VCN + subnets + security lists) | Downstream | Alta |
| IaC módulo `oci-compute` (ARM A1 + cloud-init K3s) | Downstream | Alta |
| IaC módulo `oci-lb` (Load Balancer público) | Downstream | Alta |
| Helm chart Backstage + valores para Spire | Downstream | Alta |
| Helm chart Keycloak + realm Spire pré-configurado | Downstream | Alta |
| Helm chart Kong OSS + plugin JWT + rate-limit | Downstream | Alta |
| Plugin Backstage: Spire OBC Catalog Provider | Downstream | Alta |
| Plugin Backstage: Spire Spec Validator (OpenAPI + AsyncAPI) | Downstream | Média |
| Plugin Backstage: Spire OpenSLO + CloudEvents + OPA | Downstream | Média |
| Environment local (docker-compose.yml) | Downstream | Alta |
| Script `bootstrap.sh` K3s ARM | Downstream | Alta |
| CI matrix de retrocompatibilidade Backstage | Downstream | Média |

---

# Recommendation

- [x] **Executar EXP-002** — Validar o stack localmente com docker-compose antes de OCI.
  Decisões fechadas em 2026-08-25. Pronto para iniciar EXP-002.

**Próximo passo concreto:** EXP-002 — docker-compose com Backstage + Keycloak + Kong +
Traefik + PostgreSQL + Redis + MinIO. Validar integração e sizing localmente.

---

# Knowledge Gaps Closed

| Pergunta | Status | Evidência |
|---|---|---|
| Recursos OCI Free Tier suficientes? | ✅ Respondida | 24 GB RAM / 4 OCPUs — stack estimado ~3.5 GB RAM |
| Composição do stack FOSS? | ✅ Respondida | Ver seção Stack FOSS |
| Estrutura IaC OpenTofu? | ✅ Respondida | Ver seção IaC |
| Retrocompatibilidade Backstage? | ✅ Respondida | Ver seção Retrocompatibilidade |
| Imagens ARM64 disponíveis? | ✅ Respondida | Todos os componentes têm ARM64 |
| K3s vs OKE? | ✅ Respondida | K3s — OKE cobra por nós |
| Validadores por tipo de spec? | ✅ Respondida | Ver tabela Validadores |
| MinIO vs OCI Object Storage? | ✅ Respondida | OCI: Object Storage nativo (grátis). Local: MinIO |
| Traefik vs nginx-ingress? | ✅ Respondida | Traefik — built-in K3s, zero overhead |
| Single-node vs 2 nós? | ✅ Respondida | Single-node para referência |

---

# Exit Criteria

- [x] Hipótese H1 respondida (sizing OCI Free Tier — ✅ suficiente)
- [x] Hipótese H2 respondida (modelo de plugins Backstage — ✅ viável)
- [x] Hipótese H3 respondida (arquitetura plugável por spec — ✅ viável)
- [x] Perguntas classificadas
- [x] Impacto arquitetural documentado
- [ ] Validação local (docker-compose) — próximo experimento
- [x] Recomendação produzida

---

# Next Step

Executar EXP-002 — Validação local do stack com docker-compose antes de escrever o IaC OCI.
