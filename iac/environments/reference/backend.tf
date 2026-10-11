# State local — OCI Object Storage S3 compat não suporta chunked encoding (PutObject).
# Para migrar para remote state no futuro:
#   1. Configurar Customer Secret Key (ver .env.terraform)
#   2. Restaurar bloco terraform { backend "s3" { ... } }
#   3. terraform init -migrate-state
#
# Backend S3 (referência para migração futura):
#   bucket    = "spire-tfstate"
#   key       = "reference/terraform.tfstate"
#   endpoints = { s3 = "https://idkj2uyatzrj.compat.objectstorage.us-ashburn-1.oraclecloud.com" }
