# State remoto no OCI Object Storage via API S3-compatível.
#
# Pré-requisito: criar o bucket manualmente antes do primeiro `terraform init`:
#   oci os bucket create --name spire-tfstate --compartment-id <compartment_ocid>
#
# Preencher <namespace> com o Object Storage namespace da sua tenancy:
#   oci os ns get
#
# Credenciais: configurar Customer Secret Key no OCI Console (IAM → Users → Customer Secret Keys)
# e exportar como variáveis de ambiente:
#   export AWS_ACCESS_KEY_ID=<customer_secret_key_id>
#   export AWS_SECRET_ACCESS_KEY=<customer_secret_key>

terraform {
  backend "s3" {
    bucket   = "spire-tfstate"
    key      = "reference/terraform.tfstate"
    region   = "us-ashburn-1"

    # Substituir <namespace> pelo namespace da tenancy OCI
    endpoint = "https://<namespace>.compat.objectstorage.us-ashburn-1.oraclecloud.com"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}
