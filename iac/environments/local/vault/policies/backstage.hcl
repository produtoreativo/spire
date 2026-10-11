path "secret/data/backstage" {
  capabilities = ["read", "list"]
}

path "secret/data/backstage/*" {
  capabilities = ["read", "list"]
}

path "secret/data/keycloak" {
  capabilities = ["read"]
}

path "secret/data/seaweedfs" {
  capabilities = ["read"]
}

path "secret/data/postgres" {
  capabilities = ["read"]
}

path "database/creds/backstage" {
  capabilities = ["read"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}
