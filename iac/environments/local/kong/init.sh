#!/bin/sh
set -e

KONG_ADMIN="http://kong:8001"
KEYCLOAK_URL="https://keycloak.spire.localhost"
REALM="spire"
OPA_URL="http://opa:8181"

# ─── Wait for Kong Admin API ──────────────────────────────────────────────────
echo "→ Waiting for Kong Admin API..."
until curl -sf "$KONG_ADMIN/status" > /dev/null 2>&1; do
  sleep 3
done
echo "✓ Kong ready."

# ─── Helper: create plugin only if not already present ───────────────────────
plugin_exists() {
  local scope="$1"   # e.g. "services/backstage-api" or ""
  local name="$2"
  local path="${scope:+/$scope}/plugins"
  curl -sf "$KONG_ADMIN$path" 2>/dev/null | grep -q "\"name\":\"$name\""
}

# ─── Services (PUT = idempotent) ──────────────────────────────────────────────
echo "→ Creating services..."

curl -sf -X PUT "$KONG_ADMIN/services/backstage-api" \
  --data "url=http://backstage:7007" \
  --data "name=backstage-api" > /dev/null

curl -sf -X PUT "$KONG_ADMIN/services/spire-specs-api" \
  --data "url=http://backstage:7007/api/spire" \
  --data "name=spire-specs-api" > /dev/null

curl -sf -X PUT "$KONG_ADMIN/services/spire-governance-api" \
  --data "url=http://backstage:7007/api/spire-governance" \
  --data "name=spire-governance-api" \
  --data "tags[]=spire" \
  --data "tags[]=governance" > /dev/null

echo "  ✓ Services created."

# ─── Routes (PUT = idempotent) ────────────────────────────────────────────────
echo "→ Creating routes..."

curl -sf -X PUT "$KONG_ADMIN/services/backstage-api/routes/backstage-api-route" \
  --data "hosts[]=api.spire.localhost" \
  --data "paths[]=/backstage" \
  --data "strip_path=true" > /dev/null

curl -sf -X PUT "$KONG_ADMIN/services/spire-specs-api/routes/spire-specs-route" \
  --data "hosts[]=api.spire.localhost" \
  --data "paths[]=/specs" \
  --data "strip_path=false" > /dev/null

curl -sf -X PUT "$KONG_ADMIN/services/spire-governance-api/routes/spire-governance-route" \
  --data "hosts[]=api.spire.localhost" \
  --data "paths[]=/spire/api/governance" \
  --data "strip_path=true" \
  --data "methods[]=POST" \
  --data "methods[]=GET" \
  --data "tags[]=spire" \
  --data "tags[]=governance" > /dev/null

echo "  ✓ Routes created."

# ─── Global plugins ───────────────────────────────────────────────────────────
echo "→ Configuring global plugins..."

if ! plugin_exists "" "correlation-id"; then
  curl -sf -X POST "$KONG_ADMIN/plugins" \
    --data "name=correlation-id" \
    --data "config.header_name=X-Spire-Request-ID" \
    --data "config.generator=uuid#counter" \
    --data "config.echo_downstream=true" > /dev/null
  echo "  ✓ correlation-id added."
else
  echo "  – correlation-id already present."
fi

# ─── oidcify: JWT validation (Keycloak) ──────────────────────────────────────
# Applied per-service so each can be individually enabled/disabled.
echo "→ Configuring oidcify plugin..."

for SVC in backstage-api spire-specs-api spire-governance-api; do
  if ! plugin_exists "services/$SVC" "oidcify"; then
    curl -sf -X POST "$KONG_ADMIN/services/$SVC/plugins" \
      --data "name=oidcify" \
      --data "config.issuer=${KEYCLOAK_URL}/realms/${REALM}" \
      --data "config.client_id=kong" \
      --data "config.client_secret=${KONG_KEYCLOAK_CLIENT_SECRET}" \
      --data "config.redirect_uri=${KEYCLOAK_URL}/_oauth" \
      --data "config.consumer_name=kong" \
      --data "config.bearer_jwt_allowed_auds[]=kong" \
      --data "config.bearer_jwt_allowed_algs[]=RS256" \
      --data "config.id_token_claims_header=X-User-Claims" \
      --data "config.redirect_unauthenticated=false" \
      --data "config.use_pkce=false" \
      --data "config.use_userinfo=false" \
      --data "config.static_provider_config.jwks_uri=${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/certs" \
      --data "config.static_provider_config.token_endpoint=${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
      --data "config.static_provider_config.authorization_endpoint=${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/auth" \
      --data "config.static_provider_config.userinfo_endpoint=${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/userinfo" \
      --data "config.static_provider_config.id_token_signing_alg_values_supported[]=RS256" > /dev/null
    echo "  ✓ oidcify added to $SVC."
  else
    echo "  – oidcify already present on $SVC."
  fi
done

# ─── kong-opafy: authorization via OPA ───────────────────────────────────────
echo "→ Configuring kong-opafy plugin..."

for SVC in backstage-api spire-specs-api spire-governance-api; do
  if ! plugin_exists "services/$SVC" "kong-opafy"; then
    curl -sf -X POST "$KONG_ADMIN/services/$SVC/plugins" \
      --data "name=kong-opafy" \
      --data "config.opa_url=${OPA_URL}" > /dev/null
    echo "  ✓ kong-opafy added to $SVC."
  else
    echo "  – kong-opafy already present on $SVC."
  fi
done

# ─── request-transformer: replace Bearer JWT with static pipeline token ────────
echo "→ Configuring request-transformer on spire-governance-api..."
if ! plugin_exists "services/spire-governance-api" "request-transformer"; then
  curl -sf -X POST "$KONG_ADMIN/services/spire-governance-api/plugins" \
    --data "name=request-transformer" \
    --data "config.remove.headers[]=Authorization" \
    --data "config.add.headers[]=Authorization:Bearer ${BACKSTAGE_PIPELINE_TOKEN}" > /dev/null
  echo "  ✓ request-transformer added to spire-governance-api."
else
  echo "  – request-transformer already present on spire-governance-api."
fi

# ─── Rate limiting (per service) ─────────────────────────────────────────────
echo "→ Configuring rate-limiting..."

if ! plugin_exists "services/backstage-api" "rate-limiting"; then
  curl -sf -X POST "$KONG_ADMIN/services/backstage-api/plugins" \
    --data "name=rate-limiting" \
    --data "config.minute=100" \
    --data "config.policy=local" > /dev/null
  echo "  ✓ rate-limiting added to backstage-api."
fi

if ! plugin_exists "services/spire-specs-api" "rate-limiting"; then
  curl -sf -X POST "$KONG_ADMIN/services/spire-specs-api/plugins" \
    --data "name=rate-limiting" \
    --data "config.minute=60" \
    --data "config.policy=local" > /dev/null
  echo "  ✓ rate-limiting added to spire-specs-api."
fi

if ! plugin_exists "services/spire-governance-api" "rate-limiting"; then
  curl -sf -X POST "$KONG_ADMIN/services/spire-governance-api/plugins" \
    --data "name=rate-limiting" \
    --data "config.minute=30" \
    --data "config.policy=local" > /dev/null
  echo "  ✓ rate-limiting added to spire-governance-api."
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "┌──────────────────────────────────────────────────────────────────┐"
echo "│  Kong configured (EXP-008)                                      │"
echo "│                                                                  │"
echo "│  Services:  backstage-api  spire-specs-api                      │"
echo "│             spire-governance-api (/spire/api/governance/*)      │"
echo "│  Plugins:   oidcify (JWT) → kong-opafy (OPA)                    │"
echo "│             request-transformer (pipeline token injection)       │"
echo "│             rate-limiting                                        │"
echo "│                                                                  │"
echo "│  Test token:  make kong-token                                   │"
echo "│  Submit:      make spire-submit                                 │"
echo "└──────────────────────────────────────────────────────────────────┘"

echo "✓ Kong init complete."
