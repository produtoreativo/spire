storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

ui            = true
disable_mlock = true

# Public API address (behind Traefik TLS)
api_addr = "https://vault.spire.localhost"
