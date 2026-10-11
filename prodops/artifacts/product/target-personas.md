# Spire — Target Personas

## Persona 1 — Engenheiro de Plataforma

**Contexto:** Responsável pela arquitetura e governança de múltiplos serviços em uma
organização. Quer visibilidade do estado de conformidade dos serviços sem processos
manuais ou dependência de revisões humanas.

**Necessidades:**
- Visibilidade centralizada: quais serviços têm OBC válido, quais não têm
- Pipeline de submissão que qualquer time pode adotar sem dependência da plataforma
- Controle de acesso por role (spire-registrar, spire-publisher, spire-admin)
- Validação automática de artefatos contra specs públicas — não auto-reportada

**Como usa o Spire:**
- Opera a stack (Backstage + Kong + Keycloak + OPA + Vault)
- Configura policies de autorização (OPA authz.rego)
- Analisa o Backstage catalog para identificar serviços sem cobertura de OBC
- Define os templates e critérios de OBC obrigatórios para a organização
- Monitora a métrica central: serviços registrados com OBC válido

**Job-to-be-done:**
> "Quando eu olho para o Spire, eu quero saber imediatamente quais serviços da
> organização têm contratos de negócio válidos e quais estão em débito — sem
> precisar consultar ninguém."

---

## Persona 2 — Tech Lead

**Contexto:** Dono técnico de um ou mais serviços. Não quer overhead de conformidade,
mas precisa que seu serviço seja reconhecível e confiável por outros times e pela
organização.

**Necessidades:**
- Feedback imediato: meu OBC está válido ou não, e exatamente por quê
- Script simples de submissão que roda no CI sem configuração complexa
- Spec OpenAPI do serviço publicada e associada ao catalog automaticamente
- Visibilidade do serviço no Backstage sem ter que operar a plataforma

**Como usa o Spire:**
- Adiciona `catalog-info.yaml` e `api/openapi.yaml` ao repositório do serviço
- Escreve OBCs seguindo o template ProdOps (Business Outcome → Observable Events)
- Roda `scripts/spire-submit.sh` no CI/CD ou localmente
- Consulta o Backstage catalog para verificar o estado de governança do serviço

**Job-to-be-done:**
> "Quando eu submeto meu serviço ao Spire, eu quero saber imediatamente se ele
> atende ao contrato de governança — e se não atende, o que exatamente precisa
> mudar."

---

## Job-to-be-Done Compartilhado

Ambas as personas convergem em um ponto:

> **Conformidade de governança deve ser verificável de forma automática, sem
> revisão manual, com feedback claro e acionável.**
