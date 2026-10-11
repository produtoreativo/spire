#!/bin/sh
# Vault bootstrap script — idempotente.
# Executado pelo container vault-init após vault estar acessível.
set -e

VAULT_ADDR=${VAULT_ADDR:-http://vault:8200}
INIT_FILE=/vault/init/keys.txt

# ── 1. Aguarda Vault responder ──────────────────────────────────────────────
echo "→ Waiting for Vault at ${VAULT_ADDR}..."
until vault status -address="$VAULT_ADDR" 2>&1 | grep -qE "^Initialized"; do
  sleep 2
done
echo "✓ Vault is responding."

# ── 2. Inicializar se necessário ────────────────────────────────────────────
INITIALIZED=$(vault status -address="$VAULT_ADDR" 2>&1 | grep "^Initialized" | awk '{print $2}')

if [ "$INITIALIZED" = "false" ]; then
  echo "→ Initializing Vault (1 key share, threshold 1)..."
  vault operator init -address="$VAULT_ADDR" -key-shares=1 -key-threshold=1 \
    | tee "$INIT_FILE"
  echo "✓ Vault initialized. Keys saved to $INIT_FILE"
fi

# ── 3. Ler unseal key e root token ──────────────────────────────────────────
UNSEAL_KEY=$(grep "Unseal Key 1:" "$INIT_FILE" | awk '{print $NF}')
ROOT_TOKEN=$(grep "Initial Root Token:" "$INIT_FILE" | awk '{print $NF}')

if [ -z "$UNSEAL_KEY" ] || [ -z "$ROOT_TOKEN" ]; then
  echo "ERROR: Could not read keys from $INIT_FILE"
  exit 1
fi

echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  VAULT CREDENTIALS (save these in .env)                    │"
echo "│  VAULT_UNSEAL_KEY=${UNSEAL_KEY}"
echo "│  VAULT_ROOT_TOKEN=${ROOT_TOKEN}"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""

# ── 4. Unseal se necessário ─────────────────────────────────────────────────
SEALED=$(vault status -address="$VAULT_ADDR" 2>&1 | grep "^Sealed" | awk '{print $2}')

if [ "$SEALED" = "true" ]; then
  echo "→ Unsealing Vault..."
  vault operator unseal -address="$VAULT_ADDR" "$UNSEAL_KEY"
  sleep 2
  echo "✓ Vault unsealed."
fi

# ── 5. Login ────────────────────────────────────────────────────────────────
export VAULT_TOKEN="$ROOT_TOKEN"
vault login -address="$VAULT_ADDR" -no-print "$ROOT_TOKEN"

# ── 6. Secrets Engines ──────────────────────────────────────────────────────
echo "→ Enabling secrets engines..."
vault secrets enable -address="$VAULT_ADDR" -path=secret kv-v2 2>/dev/null \
  && echo "  ✓ secret/ (kv-v2)" || echo "  • secret/ already enabled"

vault secrets enable -address="$VAULT_ADDR" -path=database database 2>/dev/null \
  && echo "  ✓ database/" || echo "  • database/ already enabled"

vault secrets enable -address="$VAULT_ADDR" -path=pki pki 2>/dev/null \
  && echo "  ✓ pki/" || echo "  • pki/ already enabled"

# ── 7. Auth Methods ─────────────────────────────────────────────────────────
echo "→ Enabling auth methods..."
vault auth enable -address="$VAULT_ADDR" approle 2>/dev/null \
  && echo "  ✓ approle" || echo "  • approle already enabled"

vault auth enable -address="$VAULT_ADDR" oidc 2>/dev/null \
  && echo "  ✓ oidc" || echo "  • oidc already enabled"

# ── 8. Database Engine — PostgreSQL ─────────────────────────────────────────
echo "→ Configuring database engine (PostgreSQL)..."

vault write -address="$VAULT_ADDR" database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="backstage,kong" \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/spire?sslmode=disable" \
  username="$POSTGRES_USER" \
  password="$POSTGRES_PASSWORD"

vault write -address="$VAULT_ADDR" database/roles/backstage \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON DATABASE spire TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

vault write -address="$VAULT_ADDR" database/roles/kong \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT ALL PRIVILEGES ON DATABASE kong TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

echo "  ✓ Database engine configured."

# ── 9. KV Secrets ────────────────────────────────────────────────────────────
echo "→ Writing initial secrets to KV..."

vault kv put -address="$VAULT_ADDR" secret/seaweedfs \
  access_key="${SEAWEEDFS_ACCESS_KEY}" \
  secret_key="${SEAWEEDFS_SECRET_KEY}"

vault kv put -address="$VAULT_ADDR" secret/keycloak \
  admin_password="${KEYCLOAK_ADMIN_PASSWORD}" \
  client_secret_backstage="${KEYCLOAK_CLIENT_SECRET}" \
  client_secret_kong="${KONG_KEYCLOAK_SECRET:-kong-dev-secret}" \
  client_secret_vault="${VAULT_KEYCLOAK_CLIENT_SECRET:-vault-dev-secret}"

vault kv put -address="$VAULT_ADDR" secret/postgres \
  user="${POSTGRES_USER}" \
  password="${POSTGRES_PASSWORD}"

vault kv put -address="$VAULT_ADDR" secret/backstage \
  auth_secret="${AUTH_BACKEND_SECRET}"

echo "  ✓ Secrets written."

# ── 10. Policies ─────────────────────────────────────────────────────────────
echo "→ Writing policies..."
vault policy write -address="$VAULT_ADDR" backstage /vault/policies/backstage.hcl
vault policy write -address="$VAULT_ADDR" kong       /vault/policies/kong.hcl
vault policy write -address="$VAULT_ADDR" readonly   /vault/policies/readonly.hcl
echo "  ✓ Policies written."

# ── 11. AppRoles ─────────────────────────────────────────────────────────────
echo "→ Configuring AppRoles..."
vault write -address="$VAULT_ADDR" auth/approle/role/backstage \
  policies="backstage" token_ttl=1h token_max_ttl=24h

vault write -address="$VAULT_ADDR" auth/approle/role/kong \
  policies="kong" token_ttl=1h token_max_ttl=24h

BACKSTAGE_ROLE_ID=$(vault read -address="$VAULT_ADDR" -field=role_id auth/approle/role/backstage/role-id)
BACKSTAGE_SECRET_ID=$(vault write -address="$VAULT_ADDR" -field=secret_id -f auth/approle/role/backstage/secret-id)

echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│  BACKSTAGE APPROLE (save these in .env)                         │"
echo "│  VAULT_BACKSTAGE_ROLE_ID=${BACKSTAGE_ROLE_ID}"
echo "│  VAULT_BACKSTAGE_SECRET_ID=${BACKSTAGE_SECRET_ID}"
echo "└──────────────────────────────────────────────────────────────────┘"
echo ""

echo "  ✓ AppRoles configured."

# ── 12. OIDC Auth (Keycloak) ─────────────────────────────────────────────────
echo "→ Configuring OIDC auth (Keycloak realm spire)..."
echo "  (requires Keycloak issuer to be HTTPS — KC_HOSTNAME_URL=https://...)"

# Use @filename so the vault CLI reads PEM with newlines correctly (no shell escaping issues).
# Keycloak must be restarted with KC_HOSTNAME_URL=https://... before this step works.
if vault write -address="$VAULT_ADDR" auth/oidc/config \
  oidc_discovery_url="https://keycloak.spire.localhost/realms/spire" \
  oidc_client_id="vault" \
  oidc_client_secret="${VAULT_KEYCLOAK_CLIENT_SECRET:-vault-dev-secret}" \
  "oidc_discovery_ca_pem=@/etc/ssl/certs/spire-ca.crt" \
  default_role="reader"; then

  vault write -address="$VAULT_ADDR" auth/oidc/role/reader \
    bound_audiences="vault" \
    allowed_redirect_uris="https://vault.spire.localhost/ui/vault/auth/oidc/oidc/callback" \
    allowed_redirect_uris="https://vault.spire.localhost/oidc/callback" \
    user_claim="sub" \
    policies="readonly" \
    ttl=1h

  vault write -address="$VAULT_ADDR" auth/oidc/role/admin \
    bound_audiences="vault" \
    allowed_redirect_uris="https://vault.spire.localhost/ui/vault/auth/oidc/oidc/callback" \
    allowed_redirect_uris="https://vault.spire.localhost/oidc/callback" \
    user_claim="sub" \
    bound_claims_type="glob" \
    policies="readonly" \
    ttl=1h

  echo "  ✓ OIDC configured."
else
  echo "  ⚠ OIDC config failed — Keycloak may not yet have HTTPS issuer."
  echo "    Restart Keycloak and run: make vault-oidc"
fi

echo ""
echo "✓ Vault fully initialized and configured."
