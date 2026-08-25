output "instance_public_ip" {
  description = "IP público da instância Spire (via Load Balancer)"
  value       = module.lb.public_ip
}

output "instance_private_ip" {
  description = "IP privado da instância K3s"
  value       = module.compute.private_ip
}

output "artifact_bucket_name" {
  description = "Nome do bucket OCI Object Storage para artefatos"
  value       = module.storage.bucket_name
}

output "artifact_bucket_namespace" {
  description = "Namespace do Object Storage"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "object_storage_namespace" {
  description = "Namespace OCI para configurar o backend S3 do Terraform"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "vault_id" {
  description = "OCID do OCI Vault para secrets"
  value       = module.vault.vault_id
}

output "domains" {
  description = "Sub-domínios configurados para os serviços Spire"
  value       = local.domains
}
