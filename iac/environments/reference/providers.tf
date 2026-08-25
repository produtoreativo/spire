provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.compute.public_ip}:6443"
    client_certificate     = base64decode(module.compute.k3s_client_cert)
    client_key             = base64decode(module.compute.k3s_client_key)
    cluster_ca_certificate = base64decode(module.compute.k3s_ca_cert)
  }
}

provider "kubernetes" {
  host                   = "https://${module.compute.public_ip}:6443"
  client_certificate     = base64decode(module.compute.k3s_client_cert)
  client_key             = base64decode(module.compute.k3s_client_key)
  cluster_ca_certificate = base64decode(module.compute.k3s_ca_cert)
}
