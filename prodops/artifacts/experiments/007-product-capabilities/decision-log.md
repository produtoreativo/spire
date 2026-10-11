# EXP-007 — Decision Log

**Data:** 2026-08-27

---

## Q1 — Prioridade de valor: Time-to-governance

**Decisão:** (a) Time-to-governance.

**Rationale:** A métrica central do Spire é `serviços registrados com OBC válido`. Essa
métrica só cresce se registrar um serviço for fácil. Visibility sem adoção é dashboard
vazio. Enforçamento sem adoção gera resistência. A sequência correta é:
fácil de adotar → visível → enforçado.

**Capacidades ativadas:** C-02 (GitHub Action), C-03 (template), C-05 (feedback em PR).

---

## Q2 — Validação de OBC: server-side no Backstage plugin

**Decisão:** (c) Backstage plugin customizado — `@spire/backstage-plugin-governance-backend`.

**Rationale:** O cliente não deve carregar lógica de governança. Regras centralizadas
no Spire garantem consistência: atualizações de ruleset (Spectral, critérios de OBC)
não exigem atualização de todos os pipelines clientes. O Backstage já é o backbone
da plataforma — o plugin é a extensão natural.

**Consequências:** `spire-submit.sh` vira thin client (auth + multipart POST + relatório).
Toda a cadeia Spectral → oasdiff → oslo → Apicurio → Kong Admin API roda no plugin.

**Referência:** `ADR-009` em `prodops/artifacts/architecture/overview.md`.

---

## Q3 — Formato mínimo do Service Deck

**Decisão:** `catalog-info.yaml` + `prodops/artifacts/obcs/*.md`. Specs de API opcionais.

**Rationale:** O que governa um serviço é o OBC, não a interface técnica. Um worker ou
batch job sem API pública pode ser plenamente governado. OpenAPI e AsyncAPI habilitam
capacidades adicionais (Kong, Microcks) mas não são pré-requisito para `governed`.

**Referência:** `prodops/artifacts/product/service-model.md`.

---

## Q4 — UI: Backstage + plugins customizados

**Decisão:** (c) Backstage com plugins customizados de frontend.

**Rationale:** O Governance Plugin já vive dentro do Backstage (ADR-009). Plugins de
frontend reutilizam auth, catalog e TechDocs sem novo componente de runtime. Um portal
próprio duplicaria esforço e criaria uma segunda superfície de autenticação.

**Capacidades de frontend para EXP-009+:** governance score por serviço, dashboard de
conformidade (% serviços `governed`), formulário de submissão guiada.

---

## Q5 — Critério de "pronto para adoção externa"

**Decisão:** (b) Produto adotável — não apenas funcional, não ainda completo.

**Critérios obrigatórios (gate para EXP-009 — versão pública):**

| Critério | Verificável como |
|---|---|
| Governance Plugin funcionando end-to-end | EXP-008 concluído com evidências |
| `spire-submit.sh` thin client documentado | README + exemplo funcional |
| GitHub Action `spire-submit` publicada | Action disponível no GitHub Marketplace ou repo público |
| Template de repositório ProdOps | Repo `produtoreativo/spire-service-template` |
| ≥ 2 serviços registrados com OBC válido | payments-api + 1 novo serviço real |
| Guia de onboarding para tech leads | Documentação: instalação em < 30 min |

**Fora do critério de adoção externa:** dashboard de conformidade, governance score,
multi-tenant, OIDC federation — todos são EXP-009+ (pós adoção).
