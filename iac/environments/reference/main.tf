module "network" {
  source = "../../modules/oci-network"

  compartment_ocid = var.compartment_ocid
  name_prefix      = local.name_prefix
  tags             = local.common_tags
}

module "security" {
  source = "../../modules/oci-security"

  compartment_ocid  = var.compartment_ocid
  name_prefix       = local.name_prefix
  vcn_id            = module.network.vcn_id
  allowed_ssh_cidrs = var.allowed_ssh_cidrs
  tags              = local.common_tags
}

# Instância na subnet pública — IP público efêmero gratuito (Always Free)
# NAT Gateway removido: sem custo de processamento de dados
module "compute" {
  source = "../../modules/oci-compute"

  compartment_ocid    = var.compartment_ocid
  name_prefix         = local.name_prefix
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  image_id            = data.oci_core_images.arm_linux.images[0].id
  shape               = var.instance_shape
  ocpus               = var.instance_ocpus
  memory_gb           = var.instance_memory_gb
  fault_domain        = var.fault_domain
  subnet_id           = module.network.public_subnet_id
  nsg_ids             = [module.security.instance_nsg_id]
  ssh_public_key      = var.ssh_public_key
  tags                = local.common_tags
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

# OCI Vault removido do EXP-009 — custo por key version fora do Always Free
# Adicionar em EXP futuro quando necessário para secrets de produção
