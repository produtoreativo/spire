output "private_ip" {
  value = oci_core_instance.this.private_ip
}

output "public_ip" {
  description = "IP público da instância (Always Free ephemeral public IP)"
  value       = oci_core_instance.this.public_ip
}

# Placeholders para integração futura com provider helm/kubernetes via K3s
output "k3s_client_cert" { value = "" }
output "k3s_client_key" {
  value     = ""
  sensitive = true
}
output "k3s_ca_cert" { value = "" }
