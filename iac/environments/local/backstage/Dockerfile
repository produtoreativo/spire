# EXP-002: Use the official Backstage demo image for infrastructure validation.
# This avoids yarn 4 quarantine issues from nunjitsu (security advisory) and
# the complexity of building a custom app from scratch.
#
# EXP-003 will build a proper custom image with Spire plugins on top of this base.
# https://github.com/backstage/backstage/pkgs/container/backstage
FROM ghcr.io/backstage/backstage:latest

# Config is injected via APP_CONFIG_ env vars in docker-compose.
EXPOSE 7007

# Official Backstage image has no curl/wget — use node's built-in http module
HEALTHCHECK --interval=30s --timeout=10s --retries=10 --start-period=60s \
  CMD node -e "require('http').get('http://localhost:7007/healthcheck',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "packages/backend", "--config", "app-config.yaml"]
