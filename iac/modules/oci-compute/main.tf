locals {
  cloud_init = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    hostname = "${var.name_prefix}-node"
  }))
}

resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  fault_domain        = var.fault_domain != "" ? var.fault_domain : null
  display_name        = "${var.name_prefix}-node"
  shape               = var.shape
  freeform_tags       = var.tags

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = var.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = var.subnet_id
    nsg_ids          = var.nsg_ids
    assign_public_ip = true
    hostname_label   = replace(var.name_prefix, "-", "")
  }

  # CKV_OCI_5: desabilita endpoint IMDS legado (v1) — usar apenas IMDSv2
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  # CKV_OCI_4: criptografia em trânsito para boot volume (sem custo adicional)
  is_pv_encryption_in_transit_enabled = true

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.cloud_init
  }

  # Ignora mudanças de image_id: nova imagem Oracle Linux publicada não destrói a instância
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }

  timeouts {
    create = "20m"
  }
}
