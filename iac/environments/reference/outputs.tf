output "instance_public_ip" {
  description = "IP público da instância (acesso SSH + serviços via LB)"
  value       = module.compute.public_ip
}

output "lb_public_ip" {
  description = "IP público do Load Balancer (entry point HTTP/HTTPS)"
  value       = module.lb.public_ip
}

output "instance_private_ip" {
  description = "IP privado da instância K3s (backend do LB)"
  value       = module.compute.private_ip
}

output "ssh_command" {
  description = "Comando SSH para acessar a instância"
  value       = "ssh -i ~/.ssh/spire-oci opc@${module.compute.public_ip}"
}

output "artifact_bucket_name" {
  description = "Nome do bucket OCI Object Storage para artefatos"
  value       = module.storage.bucket_name
}

output "object_storage_namespace" {
  description = "Namespace OCI para configurar o backend S3 do Terraform"
  value       = data.oci_objectstorage_namespace.ns.namespace
}

output "domains" {
  description = "Sub-domínios configurados para os serviços Spire"
  value       = local.domains
}
