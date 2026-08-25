locals {
  cloud_init = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    hostname = "${var.name_prefix}-node"
  }))
}

resource "oci_core_instance" "this" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
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
    subnet_id              = var.subnet_id
    nsg_ids                = var.nsg_ids
    assign_public_ip       = false
    hostname_label         = replace(var.name_prefix, "-", "")
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = local.cloud_init
  }

  # Aguarda a instância ficar disponível
  timeouts {
    create = "20m"
  }
}
