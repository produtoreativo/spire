output "vault_id" {
  value = oci_kms_vault.this.id
}

output "master_key_id" {
  value = oci_kms_key.master.id
}

output "management_endpoint" {
  value = oci_kms_vault.this.management_endpoint
}
