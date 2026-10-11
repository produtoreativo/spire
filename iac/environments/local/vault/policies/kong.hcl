path "secret/data/kong/*" {
  capabilities = ["read", "list"]
}

path "secret/data/keycloak" {
  capabilities = ["read"]
}

path "database/creds/kong" {
  capabilities = ["read"]
}

path "secret/metadata/kong/*" {
  capabilities = ["list"]
}
