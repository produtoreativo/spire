module "network" {
  source = "../../modules/oci-network"

  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  tags             = local.common_tags
}

module "security" {
  source = "../../modules/oci-security"

  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  vcn_id           = module.network.vcn_id
  tags             = local.common_tags
}

module "compute" {
  source = "../../modules/oci-compute"

  compartment_ocid   = var.compartment_ocid
  name_prefix        = local.name_prefix
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  image_id           = data.oci_core_images.arm_linux.images[0].id
  shape              = var.instance_shape
  ocpus              = var.instance_ocpus
  memory_gb          = var.instance_memory_gb
  subnet_id          = module.network.private_subnet_id
  nsg_ids            = [module.security.instance_nsg_id]
  ssh_public_key     = var.ssh_public_key
  tags               = local.common_tags
}

module "lb" {
  source = "../../modules/oci-lb"

  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  subnet_id        = module.network.public_subnet_id
  instance_ip      = module.compute.private_ip
  nsg_ids          = [module.security.lb_nsg_id]
  tags             = local.common_tags
}

module "storage" {
  source = "../../modules/oci-storage"

  compartment_ocid = var.compartment_ocid
  namespace        = data.oci_objectstorage_namespace.ns.namespace
  bucket_name      = var.artifact_bucket_name
  tags             = local.common_tags
}

module "vault" {
  source = "../../modules/oci-vault"

  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  tags             = local.common_tags
}
