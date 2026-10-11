#!/usr/bin/env bash
# =============================================================================
# spire-submit.sh — Thin client for Spire Governance Platform
# =============================================================================
#
# Submits service governance artifacts to the Spire Governance Plugin.
# All validation (Spectral, oasdiff, OBC checks) runs server-side in Spire.
#
# Usage:
#   ./scripts/spire-submit.sh [options]
#
# Options:
#   --catalog FILE            catalog-info.yaml path (default: catalog-info.yaml)
#   --openapi FILE            OpenAPI spec path (default: api/openapi.yaml if exists)
#   --asyncapi FILE           AsyncAPI spec path (default: api/asyncapi.yaml if exists)
#   --slo FILE                SLO spec path (default: slo.yaml if exists)
#   --obcs DIR                OBCs directory (default: prodops/artifacts/obcs)
#   --catalog-url URL         GitHub raw URL of catalog-info.yaml for permanent registration
#   --ca-cert FILE            Path to CA cert for HTTPS (local Spire stack)
#   --service-path DIR        Root directory of the service repo (default: .)
#   --dry-run                 Print what would be submitted, do not submit
#   --help                    Show this help
#
# Required env vars:
#   SPIRE_URL                 https://api.spire.localhost
#   KEYCLOAK_URL              https://keycloak.spire.localhost
#   SPIRE_CLIENT_ID           <pipeline client id>
#   SPIRE_CLIENT_SECRET       <client secret>
#
# Optional env vars:
#   SPIRE_REALM               spire (default)
#   GITHUB_ORG                Used to build catalog URL if --catalog-url not set
#   GITHUB_REPO               Used to build catalog URL
#   GITHUB_BRANCH             main (default)
#   CA_CERT                   Path to CA cert (same as --ca-cert)
#
# Exit codes:
#   0  — governed (all checks passed)
#   1  — rejected (validation errors — fix before resubmitting)
#   2  — submission failed (network / auth error)
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()   { echo -e "${CYAN}→${RESET} $*"; }
ok()     { echo -e "${GREEN}✓${RESET} $*"; }
warn()   { echo -e "${YELLOW}⚠${RESET} $*"; }
error()  { echo -e "${RED}✗${RESET} $*" >&2; }
header() { echo -e "\n${BOLD}$*${RESET}"; }

# ── Defaults ──────────────────────────────────────────────────────────────────
SERVICE_PATH="."
CATALOG_FILE="catalog-info.yaml"
OPENAPI_FILE=""
ASYNCAPI_FILE=""
SLO_FILE=""
OBCS_DIR="prodops/artifacts/obcs"
CATALOG_URL="${CATALOG_URL:-}"
CA_CERT="${CA_CERT:-}"
DRY_RUN=false
SPIRE_REALM="${SPIRE_REALM:-spire}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog)     CATALOG_FILE="$2"; shift 2 ;;
    --openapi)     OPENAPI_FILE="$2"; shift 2 ;;
    --asyncapi)    ASYNCAPI_FILE="$2"; shift 2 ;;
    --slo)         SLO_FILE="$2"; shift 2 ;;
    --obcs)        OBCS_DIR="$2"; shift 2 ;;
    --catalog-url) CATALOG_URL="$2"; shift 2 ;;
    --ca-cert)     CA_CERT="$2"; shift 2 ;;
    --service-path) SERVICE_PATH="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --help)
      sed -n '3,50p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    *) error "Unknown option: $1"; exit 2 ;;
  esac
done

cd "$SERVICE_PATH"

# ── Required env var validation ───────────────────────────────────────────────
if [[ "${DRY_RUN}" != "true" ]]; then
  for var in SPIRE_URL KEYCLOAK_URL SPIRE_CLIENT_ID SPIRE_CLIENT_SECRET; do
    if [[ -z "${!var:-}" ]]; then
      error "Required env var $var is not set"
      exit 2
    fi
  done
fi

# ── Discover artifacts ────────────────────────────────────────────────────────
header "Spire Governance — Artifact Discovery"

[[ -f "$CATALOG_FILE" ]] || { error "catalog-info.yaml not found at '$CATALOG_FILE'"; exit 1; }
ok "catalog-info.yaml: $CATALOG_FILE"

# Auto-detect spec files if not specified
[[ -z "$OPENAPI_FILE"  && -f "api/openapi.yaml"  ]] && OPENAPI_FILE="api/openapi.yaml"
[[ -z "$ASYNCAPI_FILE" && -f "api/asyncapi.yaml" ]] && ASYNCAPI_FILE="api/asyncapi.yaml"
[[ -z "$SLO_FILE"      && -f "slo.yaml"          ]] && SLO_FILE="slo.yaml"

[[ -n "$OPENAPI_FILE"  ]] && ok "openapi.yaml: $OPENAPI_FILE"   || info "openapi.yaml: not present (optional)"
[[ -n "$ASYNCAPI_FILE" ]] && ok "asyncapi.yaml: $ASYNCAPI_FILE" || info "asyncapi.yaml: not present (optional)"
[[ -n "$SLO_FILE"      ]] && ok "slo.yaml: $SLO_FILE"           || info "slo.yaml: not present (optional)"

OBC_FILES=()
if [[ -d "$OBCS_DIR" ]]; then
  while IFS= read -r -d '' f; do
    OBC_FILES+=("$f")
  done < <(find "$OBCS_DIR" -name "*.md" ! -name "README*" -print0 2>/dev/null)
fi

if [[ ${#OBC_FILES[@]} -gt 0 ]]; then
  ok "${#OBC_FILES[@]} OBC(s) found in $OBCS_DIR"
else
  warn "No OBC files found in $OBCS_DIR (required for governed status)"
fi

# ── Build catalog URL ─────────────────────────────────────────────────────────
if [[ -z "$CATALOG_URL" && -n "${GITHUB_ORG:-}" && -n "${GITHUB_REPO:-}" ]]; then
  CATALOG_URL="https://raw.githubusercontent.com/${GITHUB_ORG}/${GITHUB_REPO}/${GITHUB_BRANCH}/catalog-info.yaml"
fi

if [[ -n "$CATALOG_URL" ]]; then
  info "Catalog URL: $CATALOG_URL"
fi

# ── Dry run ────────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  header "Dry run — would submit:"
  info "POST ${SPIRE_URL}/spire/api/governance/submit"
  info "  catalog_info: $CATALOG_FILE"
  [[ -n "$OPENAPI_FILE"  ]] && info "  openapi: $OPENAPI_FILE"
  [[ -n "$ASYNCAPI_FILE" ]] && info "  asyncapi: $ASYNCAPI_FILE"
  [[ -n "$SLO_FILE"      ]] && info "  slo: $SLO_FILE"
  for obc in "${OBC_FILES[@]}"; do info "  obc: $obc"; done
  exit 0
fi

# ── Authenticate (client_credentials) ────────────────────────────────────────
header "Authentication"

CURL_OPTS=(-sf)
[[ -n "$CA_CERT" ]] && CURL_OPTS+=(--cacert "$CA_CERT")

TOKEN_RESPONSE=$(curl "${CURL_OPTS[@]}" -X POST \
  "${KEYCLOAK_URL}/realms/${SPIRE_REALM}/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=${SPIRE_CLIENT_ID}" \
  -d "client_secret=${SPIRE_CLIENT_SECRET}" \
  2>&1) || { error "Token request failed"; exit 2; }

JWT=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
if [[ -z "$JWT" ]]; then
  error "Failed to obtain JWT. Check KEYCLOAK_URL, SPIRE_CLIENT_ID, SPIRE_CLIENT_SECRET."
  error "Response: $TOKEN_RESPONSE"
  exit 2
fi
ok "JWT obtained (client: $SPIRE_CLIENT_ID)"

# ── Build multipart form data ─────────────────────────────────────────────────
header "Submitting to Spire Governance"

SUBMIT_OPTS=(-s -X POST)  # no -f: we read the body on 4xx/5xx to show validation errors
[[ -n "$CA_CERT" ]] && SUBMIT_OPTS+=(--cacert "$CA_CERT")
SUBMIT_OPTS+=(-H "Authorization: Bearer $JWT")
SUBMIT_OPTS+=(-F "catalog_info=@${CATALOG_FILE};type=application/yaml")

for obc in "${OBC_FILES[@]}"; do
  SUBMIT_OPTS+=(-F "obcs=@${obc};type=text/markdown")
done

[[ -n "$OPENAPI_FILE"  ]] && SUBMIT_OPTS+=(-F "openapi=@${OPENAPI_FILE};type=application/yaml")
[[ -n "$ASYNCAPI_FILE" ]] && SUBMIT_OPTS+=(-F "asyncapi=@${ASYNCAPI_FILE};type=application/yaml")
[[ -n "$SLO_FILE"      ]] && SUBMIT_OPTS+=(-F "slo=@${SLO_FILE};type=application/yaml")
[[ -n "$CATALOG_URL"   ]] && SUBMIT_OPTS+=(-F "catalog_url=${CATALOG_URL}")

info "POST ${SPIRE_URL}/spire/api/governance/submit"

HTTP_STATUS=""
RESPONSE=$(curl "${SUBMIT_OPTS[@]}" \
  -w "\n__HTTP_STATUS__%{http_code}" \
  "${SPIRE_URL}/spire/api/governance/submit" 2>&1)
CURL_EXIT=$?
if [[ $CURL_EXIT -ne 0 ]]; then
  error "Connection failed (curl exit $CURL_EXIT). Is Spire reachable at $SPIRE_URL?"
  exit 2
fi

HTTP_STATUS=$(echo "$RESPONSE" | grep -o '__HTTP_STATUS__[0-9]*' | cut -d_ -f5)
BODY=$(echo "$RESPONSE" | sed 's/__HTTP_STATUS__[0-9]*$//')

# ── Display report ─────────────────────────────────────────────────────────────
header "Governance Report"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"

# ── Exit code based on status ─────────────────────────────────────────────────
STATUS=$(echo "$BODY" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

case "$STATUS" in
  "governed")
    echo ""
    ok "Service governed — all checks passed."
    exit 0
    ;;
  "governed_with_warnings")
    echo ""
    warn "Service governed with warnings — review recommended."
    exit 0
    ;;
  "rejected")
    echo ""
    error "Submission rejected — fix the errors above and resubmit."
    exit 1
    ;;
  *)
    if [[ "$HTTP_STATUS" == "2"* ]]; then
      echo ""
      ok "Submitted (status: $HTTP_STATUS)"
      exit 0
    else
      error "Unexpected response (HTTP $HTTP_STATUS): $STATUS"
      exit 2
    fi
    ;;
esac
