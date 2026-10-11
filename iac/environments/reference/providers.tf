provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

# helm e kubernetes providers serão adicionados após VM provisionada,
# lendo o kubeconfig via remote-exec ou local_file data source.
