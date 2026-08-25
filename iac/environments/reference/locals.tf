locals {
  project = "spire"
  env     = var.environment

  # Prefixo consistente para todos os recursos
  name_prefix = "${local.project}-${local.env}"

  # Tags aplicadas a todos os recursos OCI
  common_tags = {
    Project     = local.project
    Environment = local.env
    ManagedBy   = "terraform"
  }

  # Sub-domínios derivados do domínio base
  domains = {
    backstage = "backstage.${var.domain}"
    keycloak  = "keycloak.${var.domain}"
    kong_api  = "api.${var.domain}"
    grafana   = "grafana.${var.domain}"
  }
}
