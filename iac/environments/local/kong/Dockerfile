# ─── Stage 1: Build oidcify (Go OIDC plugin for Kong) ────────────────────────
FROM golang:1.23-bookworm AS builder

WORKDIR /build

# GOTOOLCHAIN=auto downloads the version required by oidcify's go.mod
ENV GOTOOLCHAIN=auto

RUN git clone https://github.com/hanlaur/oidcify.git .
RUN CGO_ENABLED=0 go build -o oidcify .

# ─── Stage 2: Kong + plugins ─────────────────────────────────────────────────
FROM kong:3.8

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl \
  && rm -rf /var/lib/apt/lists/*

# oidcify Go plugin binary
COPY --from=builder /build/oidcify /usr/local/bin/oidcify
RUN chmod +x /usr/local/bin/oidcify

# kong-opafy Lua plugin
# lua-resty-http is already bundled in kong:3.8 (/usr/local/share/lua/5.1/resty/http.lua)
# Copy plugin files to standard Lua path so Kong finds them via require("kong.plugins.kong-opafy.*")
RUN git clone https://github.com/produtoreativo/kong-opafy.git /tmp/kong-opafy \
  && mkdir -p /usr/local/share/lua/5.1/kong/plugins/kong-opafy \
  && cp /tmp/kong-opafy/kong/plugins/kong-opafy/handler.lua \
        /tmp/kong-opafy/kong/plugins/kong-opafy/schema.lua \
        /usr/local/share/lua/5.1/kong/plugins/kong-opafy/ \
  && rm -rf /tmp/kong-opafy

# Plugin declarations
ENV KONG_PLUGINS="bundled,oidcify,kong-opafy"

# oidcify runs as a Go plugin server (not inlined Lua)
ENV KONG_PLUGINSERVER_NAMES="oidcify"
ENV KONG_PLUGINSERVER_OIDCIFY_QUERY_CMD="/usr/local/bin/oidcify -dump"
ENV KONG_PLUGINSERVER_OIDCIFY_START_CMD="/usr/local/bin/oidcify"
