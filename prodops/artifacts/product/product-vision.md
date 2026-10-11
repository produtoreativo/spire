# Spire — Product Vision

## Declaração de Posicionamento

> Modelo: *Crossing the Chasm* — Geoffrey Moore

**Para**
times de engenharia de produto que operam múltiplos serviços digitais em produção

**Que precisam**
garantir que cada serviço cumpre um contrato de negócio claro, verificável e rastreável — sem depender de revisão manual ou auto-declaração de conformidade

**SPIRE é uma**
plataforma open-source de governança de serviços digitais

**Que**
vincula cada serviço a um Observable Business Contract (OBC) validado automaticamente contra specs públicas (OpenAPI, AsyncAPI), tornando auditável a evidência de que o outcome prometido é observável em produção

**Diferente**
de utilizar diretamente catálogos como Backstage, Port ou Cortex, que organizam metadata de serviços mas não estabelecem nem validam contratos de negócio

**SPIRE**
governa como os serviços são construídos e validados — não apenas onde estão catalogados

---

## O Produto

Spire é uma plataforma **open-source** de governança para engenharia, arquitetura e
serviços de produtos digitais. Construído opinativo sobre o ProdOps Framework, o Spire
organiza o conhecimento de produto e serviço em artefatos verificáveis e rastreáveis —
do Product Deck ao Observable Business Contract (OBC) de cada serviço.

## O Problema

As organizações de engenharia crescem sem um contrato claro entre o que um serviço
**promete entregar** (business outcome) e o que ele **realmente faz** (comportamento
observável em produção).

Catálogos existem — mas são metadata auto-reportada, sem validação.
Scorecards existem — mas medem qualidade técnica, não valor de negócio.
Ninguém fecha o loop entre **intenção de produto** e **evidência observável em produção**.

## A Solução

Spire trata o **Observable Business Contract (OBC)** como primitivo de governança de
primeira classe. Um serviço não está apenas "catalogado" — ele está **governado**: tem
um contrato verificável que une o resultado de negócio esperado ao evento observável que
o comprova, validado contra specs públicas (OpenAPI, AsyncAPI).

## Posicionamento

| Plataforma | Modelo | Limitação |
|---|---|---|
| Backstage (Spotify) | Catálogo + metadata | Infraestrutura sem contrato de negócio nativo |
| Port | Catálogo + scorecard customizável | Scorecard ≠ contrato de outcome |
| Cortex | Catálogo + engineering scorecard | Mede saúde técnica, não valor de negócio |
| OpsLevel | Catálogo + maturity rubric | Maturidade ≠ modelo de contrato |
| Datadog Service Catalog | Observabilidade + SLO | SLO ≠ OBC; sem camada de business value |
| **Spire** | **Governança + OBC + ProdOps** | — |

## Três Diferenciais Genuínos

**1. OBC como primitivo de governança**
Não um scorecard, mas um contrato que vincula evento observável ao resultado de negócio
esperado. Nenhum concorrente tem esse primitivo.

**2. Validação de artefato contra spec pública**
OpenAPI e AsyncAPI são validados pela pipeline antes do serviço ser registrado.
Conformidade provável e auditável — não auto-declarada.

**3. Ciclo de entrega governado (ProdOps)**
Do Product Deck ao OBC, da entrega à validação em produção. Os concorrentes catalogam
o que existe; o Spire governa como é construído e validado.

## Métrica de Sucesso Principal

> **Serviços registrados com OBC válido**

Número de serviços que passaram pela pipeline de submissão com pelo menos um OBC
com todas as seções obrigatórias (Business Outcome + Observable Events + SLIs +
Reliability Rules + Response Contract) validadas sem erros críticos.

## Distribuição

Open-source, público. Qualquer organização pode instalar e operar o Spire usando a
stack de referência documentada: Backstage + Kong + Keycloak + OPA + Vault.
