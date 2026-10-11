# Spire — Roadmap

Roadmap orientado a business outcomes. Cada item mapeado a um experimento ou business intent.
Sequência de EXPs reflete prioridade de validação de hipóteses, não de release.

---

## Entregue

| EXP | Capability | Business Outcome Validado |
|---|---|---|
| EXP-001 | OCI Infra + Backstage | Plataforma operacional em cloud pública |
| EXP-002 | Local Stack (Kong, Keycloak, Traefik, SSL) | Stack local reproduzível para desenvolvimento e contribuição open-source |
| EXP-003 | Backstage integrado (catalog, PostgreSQL, TechDocs) | Catalog funcional com entidades, grupos e documentação |
| EXP-004 | Vault integrado (AppRole, OIDC, dynamic DB creds) | Gestão de segredos sem credenciais hardcoded |
| EXP-005 | Kong + Keycloak + OPA (oidcify + kong-opafy) | Auth + RBAC para todas as rotas — apenas roles corretas chegam aos backends |
| EXP-006 | payments-api — primeiro serviço governado | Pipeline de submissão funcionando ponta a ponta: script genérico, OBC validado, serviço no catalog |

**Métrica atual:** 1 serviço registrado com OBC válido (payments-api — 28/30 OBCs passaram).

---

## Em Planejamento

### EXP-007 — Mapa de Capacidades ✅ Concluído (product discovery)

Decisões registradas em `experiments/007-product-capabilities/decision-log.md`.
Prioridade definida: time-to-governance. Produto adotável como critério de versão pública.

### EXP-008 — Governance Plugin + Time-to-Governance

**Business Outcome:** Tech leads registram um serviço com OBC válido em < 30 minutos usando o GitHub Action e o template de repositório — sem interação manual com a plataforma.

Capacidades:
- `@spire/backstage-plugin-governance-backend` — governança server-side (Spectral, oasdiff, Apicurio, Kong deck sync)
- `spire-submit.sh` refatorado como thin client
- GitHub Action reutilizável `spire-submit`
- Template de repositório ProdOps (`spire-service-template`)
- Apicurio Registry + Microcks na stack local
- ≥ 2 serviços governados com OBC válido (payments-api + novo)
- Guia de onboarding testado (< 30 min em máquina limpa)

### EXP-009 — OCI Production-Grade + Adoção Externa

**Business Outcome:** Spire está disponível como plataforma pública — qualquer organização pode adotar sem suporte direto, apontando para a instância de referência.

Capacidades:
- Migração da stack para Oracle Cloud Free Tier (Terraform EXP-001 como base)
- TLS, domínio público, health checks de produção
- Plugins de frontend: governance score + dashboard de conformidade
- Documentação de operação completa (Vault, Keycloak, Kong config)

---

## Backlog de Product

| Intent | Business Outcome Esperado | Horizon |
|---|---|---|
| Compliance dashboard | Engenheiro de plataforma vê % de serviços governados em tempo real | EXP-007+ |
| OBC validation server-side | Validação acontece no Spire, não no script cliente — auditável | EXP-007+ |
| Governance score por serviço | Tech lead vê seu serviço ranqueado por maturidade de governança | Futuro |
| Spec drift detection | Alerta quando OpenAPI diverge do comportamento real observado | Futuro |
| OBC diff / changelog | Tech lead vê o que mudou no contrato entre versões | Futuro |
| Multi-org onboarding | Organização externa registra serviços sem acesso à infra interna do Spire | EXP-008+ |
| Platform Deck para o próprio Spire | Spire governa a si mesmo com OBCs da plataforma | EXP-008+ |

---

## Métrica de Produto por Horizon

| Horizon | Meta |
|---|---|
| Agora (EXP-006 concluído) | 1 serviço governado com OBC válido |
| EXP-008 | Time-to-governance < 30 min — ≥ 2 serviços governados |
| EXP-009 | Instância pública disponível — adoção externa possível |
| Futuro | X organizações com Y serviços governados |
