# EXP-002 — Validação Local do Stack (docker-compose)

## Status

- [x] Completed

**Iniciado em:** 2026-08-25
**Depende de:** EXP-001

---

# Business Goal

Validar que o stack FOSS definido no EXP-001 sobe localmente, integra corretamente e
cabe nos recursos disponíveis antes de escrever o IaC para OCI.

---

# Repository Scope Gate

✅ Em escopo — IaC e ambiente local são responsabilidade direta do Spire.

---

# Questions to Answer

1. O stack sobe sem conflitos de porta, versão ou dependência?
2. Backstage autentica via Keycloak (OIDC)?
3. Kong valida JWT emitido pelo Keycloak?
4. Traefik roteia para todos os serviços via hostname local?
5. O sizing de RAM é compatível com máquinas de desenvolvimento comuns (8–16 GB)?

---

# Hypothesis

O stack completo sobe em menos de 5 minutos numa máquina com 8 GB RAM disponíveis,
com Backstage acessível via `http://backstage.spire.localhost` autenticado por Keycloak.

---

# Scope

- `docker-compose.yml` com todos os serviços do stack
- `.env.example` com todas as variáveis de configuração
- `keycloak/realm-spire.json` — realm pré-configurado (exportado)
- `kong/kong.yml` — declarative config (DB-less mode para local)
- `traefik/traefik.yml` — configuração estática
- Script `make up` / `make down` / `make logs`
- Validação manual: Backstage acessível + login via Keycloak

---

# Out of Scope

- Plugins Backstage (experimento posterior)
- TLS em local (usar HTTP simples com `.localhost`)
- Volumes persistentes entre restarts (dev only)
- Prometheus/Grafana (simplificar para validação de sizing)

---

# Implementation Plan

1. Criar `iac/environments/local/docker-compose.yml`
2. Criar `iac/environments/local/.env.example`
3. Criar `iac/environments/local/keycloak/realm-spire.json`
4. Criar `iac/environments/local/kong/kong.yml`
5. Criar `iac/environments/local/traefik/traefik.yml`
6. Criar `iac/environments/local/Makefile`
7. Testar `make up` e validar health checks
8. Registrar evidências

---

# Artifacts Updated

- `iac/environments/local/` — criado
- `prodops/artifacts/experiments/002-local-stack/upstream-trail.md`
