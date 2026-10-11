# ATENÇÃO: Este módulo gera CUSTO — não está no Always Free Tier.
# OCI KMS Vault (DEFAULT) ≈ $49/mês + $1/mês por key version.
# Não instanciar no ambiente reference.
resource "oci_kms_vault" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-vault"
  vault_type     = "DEFAULT"
  freeform_tags  = var.tags
}

resource "oci_kms_key" "master" {
  compartment_id      = var.compartment_ocid
  display_name        = "${var.name_prefix}-master-key"
  management_endpoint = oci_kms_vault.this.management_endpoint
  freeform_tags       = var.tags

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}
