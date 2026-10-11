resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-vcn"
  cidr_blocks    = [var.vcn_cidr]
  dns_label      = replace(var.name_prefix, "-", "")
  freeform_tags  = local.freeform_tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-igw"
  enabled        = true
  freeform_tags  = local.freeform_tags
}

# Route table pública — tráfego de saída via Internet Gateway (usada por LB e instância)
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-public"
  freeform_tags  = local.freeform_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

# Subnet pública — Load Balancer e instância (IP público gratuito no Always Free)
resource "oci_core_subnet" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-subnet-public"
  cidr_block     = var.public_subnet_cidr
  route_table_id = oci_core_route_table.public.id
  dns_label      = "public"
  freeform_tags  = local.freeform_tags
}

# Route table privada — explicitamente vazia, sem saída para internet
# Evita herdar a default route table da VCN (não gerenciada pelo Terraform)
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.name_prefix}-rt-private"
  freeform_tags  = local.freeform_tags
}

# Subnet privada — reservada para uso futuro (sem NAT, sem saída para internet)
resource "oci_core_subnet" "private" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  display_name               = "${var.name_prefix}-subnet-private"
  cidr_block                 = var.private_subnet_cidr
  route_table_id             = oci_core_route_table.private.id
  prohibit_public_ip_on_vnic = true
  dns_label                  = "private"
  freeform_tags              = local.freeform_tags
}
