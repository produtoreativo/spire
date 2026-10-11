# EXP-005 — Upstream Trail (Kong + Keycloak OIDC + OPA)

Experimento: [experiment.md](experiment.md)

---

# History

## 2026-08-26 — Planejamento

### Activity

Experimento planejado. Plano de experimentos atualizado: Kong + Keycloak + OPA inserido
como EXP-005 (próximo após Vault). Plugins de negócio no Backstage replanejados como EXP-006.

Referência estudada: `produtoreativo/pre` — `aula-10/` (stack completo com Keycloak,
Kong custom, OPA e políticas Rego). Plugin OPA: `produtoreativo/kong-opafy`.

### Contexto da decisão

EXP-004 fechou o gap de secrets management (Vault). O próximo gap crítico é autorização no
API Gateway: Kong está no stack sem autenticação nem políticas. EXP-005 adiciona dois plugins
OSS ao Kong (`oidcify` para OIDC/JWT + `kong-opafy` para OPA) com políticas Rego centralizadas.

### Decision

Experimento aprovado para execução.

### Artifacts Updated

- `prodops/artifacts/experiments/005-kong-oidc-opa/experiment.md` (criado)
- `prodops/artifacts/experiments/005-kong-oidc-opa/upstream-trail.md` (criado)

---

## 2026-08-26 — Implementação e Validação

### Activity

Implementação completa do EXP-005 em sessão única (retomada de contexto anterior).

**Fases executadas:**

1. **Kong Custom Image** — Dockerfile multi-stage (golang:1.23 + kong:3.8). Descoberta:
   `luarocks install lua-resty-http` falha por constant limit do LuaJIT 5.1. Solução: copiar
   kong-opafy diretamente para `/usr/local/share/lua/5.1/` (lua-resty-http já bundled).

2. **OPA** — Adicionado ao docker-compose. Descoberta: imagens opa não têm wget/curl.
   Healthcheck via `opa eval --fail -d /policies data.authz`. Rego syntax: `startswith` é
   função, não operador infix.

3. **Keycloak/oidcify** — Três problemas descobertos e resolvidos:
   - `--import-realm` não reimporta realm existente → fixar via Admin API
   - Declarative User Profile exige `firstName`/`lastName` → `"Account is not fully set up"`
   - Keycloak não emite `aud` claim por default → adicionar `oidc-audience-mapper`

4. **OPA RBAC** — `X-User-Claims` é base64-encoded JSON (não JSON puro). Rego precisa de
   `base64.decode()` antes de `json.unmarshal()`. Sem isso, `claims` fica undefined e `allow=false`.

5. **Validação end-to-end** confirmada via OPA decision logs:
   - `spire-admin` GET → `allow=True` (gateway passa)
   - `spire-publisher` POST em `/backstage` → `allow=False` (kong-opafy retorna 403)
   - `spire-publisher` GET → `allow=True` (Backstage retorna 401 por auth próprio — escopo EXP-006)

### Decision

EXP-005 **concluído**. Hipótese confirmada: Kong OSS + oidcify + kong-opafy + OPA é viável
para autorização de API sem Kong Enterprise. Políticas Rego centralizadas funcionam.

Limitação identificada: Backstage não confia em JWT externo passado pelo Kong. EXP-006
deve resolver esse trust gap.

### Artifacts Updated

- `iac/environments/local/kong/Dockerfile` — imagem custom final
- `iac/environments/local/kong/init.sh` — `bearer_jwt_allowed_auds[]=kong` (corrigido)
- `iac/environments/local/opa/policies/authz.rego` — `base64.decode()` adicionado
- `iac/environments/local/keycloak/realm-spire.json` — audience mapper + firstName/lastName
- `prodops/artifacts/experiments/005-kong-oidc-opa/experiment.md` — status: Completed
