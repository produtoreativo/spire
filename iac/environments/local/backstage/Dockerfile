# EXP-004/EXP-008: Custom Backstage image for Spire IDP.
#
# Build context = repo root (set in docker-compose.yml).
# This allows COPY of packages/governance-backend/ from the monorepo structure.
#
# Plugins added via yarn:
#   - @backstage/plugin-auth-backend-module-oidc-provider (Keycloak OIDC)
#   - @backstage/plugin-vault-backend (Vault secrets)
#
# Plugins built from source:
#   - @spire/backstage-plugin-governance-backend  ← packages/governance-backend/
FROM ghcr.io/backstage/backstage:latest

USER root

# ── Install npm plugins + governance plugin runtime deps ────────────────────
WORKDIR /app/packages/backend

RUN yarn add \
  @backstage/plugin-auth-backend-module-oidc-provider@0.4.19 \
  @backstage/plugin-vault-backend \
  multer@^1.4.5-lts.1 \
  js-yaml@^4.1.0

# ── Install spec tooling binaries ───────────────────────────────────────────
# Spectral CLI for OpenAPI lint
RUN npm install -g @stoplight/spectral-cli@^6.0.0

# oasdiff binary for OpenAPI breaking change detection (ADR-010)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl && rm -rf /var/lib/apt/lists/* && \
  ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/') && \
  curl -sSL \
    "https://github.com/tufin/oasdiff/releases/download/v1.10.14/oasdiff_1.10.14_linux_${ARCH}.tar.gz" \
    -o /tmp/oasdiff.tar.gz && \
  tar -xz -C /usr/local/bin -f /tmp/oasdiff.tar.gz oasdiff && \
  rm /tmp/oasdiff.tar.gz && \
  chmod +x /usr/local/bin/oasdiff

# ── Build governance plugin (TypeScript → CommonJS) ─────────────────────────
# Source: packages/governance-backend/ (first-class package in the repo)
COPY packages/governance-backend /build/governance-backend
WORKDIR /build/governance-backend
RUN npm install --include=dev && npm run build

# Copy compiled output into Backstage dist for dynamic import
RUN mkdir -p /app/packages/backend/dist/plugins && cp -r dist /app/packages/backend/dist/plugins/governance-backend

# ── Override backend entry point ────────────────────────────────────────────
COPY iac/environments/local/backstage/patches/index.cjs.js \
  /app/packages/backend/dist/index.cjs.js

WORKDIR /app
USER node

EXPOSE 7007

HEALTHCHECK --interval=30s --timeout=10s --retries=10 --start-period=120s \
  CMD node -e "require('http').get('http://localhost:7007/healthcheck',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.local.yaml"]
