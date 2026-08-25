output "private_ip" {
  value = oci_core_instance.this.private_ip
}

output "public_ip" {
  description = "IP público (via LB — a instância está em subnet privada)"
  value       = oci_core_instance.this.private_ip
}

# Os outputs k3s_* são preenchidos pelo cloud-init e recuperados via remote-exec
# em um data source externo. Placeholder para integração futura com provider helm/kubernetes.
output "k3s_client_cert" { value = "" }
output "k3s_client_key"  { value = ""; sensitive = true }
output "k3s_ca_cert"     { value = "" }
