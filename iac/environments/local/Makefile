.PHONY: up down logs ps restart clean env-check certs vault-token vault-oidc kong-build kong-token kong-validate kong-configure spire-submit governance-health

ENV_FILE := .env
CERTS_DIR := traefik/certs

env-check:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "⚠  .env not found. Copying .env.example..."; \
		cp .env.example $(ENV_FILE); \
		echo "✓  .env created. Review and set required values before running 'make up'."; \
		exit 1; \
	fi

certs:
	@echo "→ Generating local CA and wildcard cert for *.spire.localhost..."
	@chmod +x $(CERTS_DIR)/generate.sh && $(CERTS_DIR)/generate.sh
	@echo ""
	@echo "→ Trust the CA in your system (required for HTTPS in browser):"
	@echo "  macOS:  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $(CERTS_DIR)/spire-ca.crt"
	@echo "  Linux:  sudo cp $(CERTS_DIR)/spire-ca.crt /usr/local/share/ca-certificates/spire-local-ca.crt && sudo update-ca-certificates"

up: env-check
	@echo "→ Starting Spire local stack..."
	@chmod +x postgres/init-multiple-dbs.sh
	docker-compose --env-file $(ENV_FILE) up -d --build
	@echo ""
	@echo "✓ Stack running. All services on HTTPS:"
	@echo ""
	@echo "  Traefik dashboard : http://localhost:8080    (HTTP, local only)"
	@echo "  Backstage         : https://backstage.spire.localhost"
	@echo "  Keycloak          : https://keycloak.spire.localhost"
	@echo "  Vault             : https://vault.spire.localhost"
	@echo "  Kong Admin        : https://kong-admin.spire.localhost"
	@echo "  API (Kong)        : https://api.spire.localhost"
	@echo "  SeaweedFS UI      : https://seaweedfs.spire.localhost"
	@echo "  Artifacts (S3)    : https://artifacts.spire.localhost"
	@echo ""
	@echo "  OPA (policies)        : http://localhost:8181 (internal)"
	@echo "  Apicurio Registry     : https://registry.spire.localhost"
	@echo "  Microcks              : https://microcks.spire.localhost"
	@echo ""
	@echo "  /etc/hosts (or use dnsmasq/NextDNS):"
	@echo "  127.0.0.1 backstage.spire.localhost keycloak.spire.localhost vault.spire.localhost"
	@echo "  127.0.0.1 kong-admin.spire.localhost api.spire.localhost"
	@echo "  127.0.0.1 seaweedfs.spire.localhost artifacts.spire.localhost"
	@echo "  127.0.0.1 registry.spire.localhost microcks.spire.localhost"
	@echo ""
	@echo "  Vault tokens appear in vault-init logs:"
	@echo "  make vault-token"

vault-token:
	@echo "→ Vault credentials from first-run init:"
	@docker logs spire-vault-init 2>&1 | grep -E "VAULT_(ROOT_TOKEN|UNSEAL_KEY|BACKSTAGE_ROLE_ID|BACKSTAGE_SECRET_ID)="

vault-oidc:
	@echo "→ Re-running Vault OIDC configuration (Keycloak must have HTTPS issuer)..."
	docker-compose --env-file $(ENV_FILE) run --rm vault-init

kong-build:
	@echo "→ Building custom Kong image (oidcify + kong-opafy)..."
	docker-compose --env-file $(ENV_FILE) build kong kong-migrations

kong-configure:
	@echo "→ Re-running Kong init (services, routes, plugins)..."
	docker-compose --env-file $(ENV_FILE) run --rm kong-init

kong-token:
	@echo "→ Getting Keycloak token for Kong validation tests..."
	@echo "  User: admin  (role: spire-admin)"
	@curl -sk -X POST \
	  "https://keycloak.spire.localhost/realms/spire/protocol/openid-connect/token" \
	  --resolve "keycloak.spire.localhost:443:127.0.0.1" \
	  --cacert $(CERTS_DIR)/spire-ca.crt \
	  -d "client_id=kong" \
	  -d "client_secret=$$KONG_KEYCLOAK_CLIENT_SECRET" \
	  -d "username=admin" \
	  -d "password=admin" \
	  -d "grant_type=password" \
	  -d "scope=openid" | python3 -c "import json,sys; d=json.load(sys.stdin); print('TOKEN=' + d['access_token'])"

kong-validate:
	@echo "→ Validating Kong routes (requires KONG_TOKEN env var)..."
	@echo "  Without token → 401:"
	@curl -sk --resolve "api.spire.localhost:443:127.0.0.1" \
	  --cacert $(CERTS_DIR)/spire-ca.crt \
	  -o /dev/null -w "  HTTP %{http_code}\n" \
	  "https://api.spire.localhost/backstage/api/catalog/entities"
	@echo "  With token → 200 (if backstage healthy):"
	@curl -sk --resolve "api.spire.localhost:443:127.0.0.1" \
	  --cacert $(CERTS_DIR)/spire-ca.crt \
	  -H "Authorization: Bearer $$KONG_TOKEN" \
	  -o /dev/null -w "  HTTP %{http_code}\n" \
	  "https://api.spire.localhost/backstage/api/catalog/entities"

spire-submit:
	@echo "→ Submitting payments-api to Spire Governance (EXP-008)..."
	@echo "  Requires: SPIRE_CLIENT_SECRET env var"
	@cd ../../.. && \
	  SPIRE_URL=https://api.spire.localhost \
	  KEYCLOAK_URL=https://keycloak.spire.localhost \
	  SPIRE_CLIENT_ID=payments-api-pipeline \
	  SPIRE_CLIENT_SECRET=$${SPIRE_CLIENT_SECRET:?set SPIRE_CLIENT_SECRET} \
	  CA_CERT=$(CURDIR)/traefik/certs/spire-ca.crt \
	  scripts/spire-submit.sh --service-path ../payments-api

governance-health:
	@echo "→ Checking Governance Plugin health..."
	@curl -sk --resolve "api.spire.localhost:443:127.0.0.1" \
	  --cacert $(CERTS_DIR)/spire-ca.crt \
	  "https://api.spire.localhost/spire/api/governance/health" | python3 -m json.tool

down:
	docker-compose --env-file $(ENV_FILE) down

logs:
	docker-compose --env-file $(ENV_FILE) logs -f --tail=50

ps:
	docker-compose --env-file $(ENV_FILE) ps

restart:
	docker-compose --env-file $(ENV_FILE) restart $(svc)

clean:
	docker-compose --env-file $(ENV_FILE) down -v --remove-orphans
	@echo "✓ Volumes and containers removed."

# Abre shell num serviço: make shell svc=keycloak
shell:
	docker-compose --env-file $(ENV_FILE) exec $(svc) sh
