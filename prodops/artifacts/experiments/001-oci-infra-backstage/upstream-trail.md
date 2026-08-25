# Upstream Trail — EXP-001

## 2026-08-25 — Sessão inicial

**Operador:** Christiano Milfont

**Ações:**
- Criado experimento EXP-001 — IaC OCI Free Tier + Backstage FOSS Stack
- Mapeados recursos OCI Always Free e sizing do stack
- Definida arquitetura de rede OCI (VCN + subnets + LB)
- Definida composição FOSS: K3s, Backstage, Keycloak, Kong, PostgreSQL, Redis, MinIO
- Mapeados validadores FOSS por tipo de spec (OpenAPI, OpenSLO, AsyncAPI, CloudEvents, OTel, OPA)
- Definida estrutura de módulos OpenTofu
- Definida estratégia de retrocompatibilidade de plugins Backstage
- Confirmado que todos os componentes têm imagens ARM64

**Resultado:** Hipóteses H1, H2, H3 respondidas. Decisões abertas identificadas.
Recomendação: EXP-002 com docker-compose antes de IaC OCI.

**Status:** Em progresso — aguardando discussão do plano com o operador.
