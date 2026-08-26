FROM node:20-alpine

# Build deps for node-gyp and sqlite3
RUN apk add --no-cache git python3 make g++ curl bash

# Scaffold Backstage app (layer cached after first build)
# --path flag required since create-app dropped positional arg for the app name
WORKDIR /build
RUN npx --yes @backstage/create-app@latest --skip-install --path spire

WORKDIR /build/spire

# Install all workspace dependencies (layer cached until package.json/yarn.lock changes)
RUN yarn install --frozen-lockfile --network-timeout 300000

# Config overlay (mounted last so it doesn't bust the yarn cache layer)
COPY app-config.local.yaml ./app-config.local.yaml

EXPOSE 7007

HEALTHCHECK --interval=30s --timeout=10s --retries=10 --start-period=180s \
  CMD curl -f http://localhost:7007/healthcheck || exit 1

# Config is injected via APP_CONFIG_ env vars in docker-compose (avoids path resolution issues
# with yarn workspace workspace-root vs package-dir CWD ambiguity across yarn versions).
CMD ["yarn", "workspace", "backend", "start"]
