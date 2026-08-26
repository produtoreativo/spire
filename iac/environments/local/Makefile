.PHONY: up down logs ps restart clean env-check

ENV_FILE := .env

env-check:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo "⚠  .env not found. Copying .env.example..."; \
		cp .env.example $(ENV_FILE); \
		echo "✓  .env created. Review and set required values before running 'make up'."; \
		exit 1; \
	fi

up: env-check
	@echo "→ Starting Spire local stack..."
	@chmod +x postgres/init-multiple-dbs.sh
	docker-compose --env-file $(ENV_FILE) up -d --build
	@echo ""
	@echo "✓ Stack running. Services:"
	@echo "  Traefik dashboard : http://localhost:8080"
	@echo "  Backstage         : http://backstage.spire.localhost"
	@echo "  Keycloak          : http://keycloak.spire.localhost"
	@echo "  Kong Admin        : http://kong-admin.spire.localhost"
	@echo "  MinIO Console     : http://minio.spire.localhost"
	@echo ""
	@echo "  Add to /etc/hosts (or use a DNS resolver like dnsmasq/NextDNS):"
	@echo "  127.0.0.1 backstage.spire.localhost keycloak.spire.localhost"
	@echo "  127.0.0.1 kong-admin.spire.localhost api.spire.localhost"
	@echo "  127.0.0.1 minio.spire.localhost artifacts.spire.localhost"

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
