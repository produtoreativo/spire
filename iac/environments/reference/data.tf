# Availability Domain disponível na região
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# Imagem Oracle Linux 9 para ARM (usada no cloud-init)
data "oci_core_images" "arm_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

# Object Storage namespace da tenancy (necessário para o backend S3)
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}
