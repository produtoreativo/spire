# ── OCI Auth ──────────────────────────────────────────────────────────────────

variable "tenancy_ocid" {
  description = "OCID da tenancy OCI"
  type        = string
}

variable "user_ocid" {
  description = "OCID do usuário OCI para autenticação"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint da chave API OCI"
  type        = string
}

variable "private_key_path" {
  description = "Caminho local para a chave privada OCI (.pem)"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "Região OCI (ex: us-ashburn-1, sa-saopaulo-1)"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_ocid" {
  description = "OCID do compartimento onde os recursos serão criados"
  type        = string
}

# ── Compute ───────────────────────────────────────────────────────────────────

variable "instance_shape" {
  description = "Shape da instância OCI"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  description = "Número de OCPUs (máximo 4 no Free Tier)"
  type        = number
  default     = 4
}

variable "instance_memory_gb" {
  description = "RAM em GB (máximo 24 no Free Tier)"
  type        = number
  default     = 24
}

variable "ssh_public_key" {
  description = "Chave SSH pública para acesso à instância"
  type        = string
  sensitive   = true
}

# ── DNS / Domínio ─────────────────────────────────────────────────────────────

variable "domain" {
  description = "Domínio base do Spire (ex: spire.example.com)"
  type        = string
}

# ── Storage ───────────────────────────────────────────────────────────────────

variable "artifact_bucket_name" {
  description = "Nome do bucket OCI Object Storage para artefatos OBC"
  type        = string
  default     = "spire-artifacts"
}

# ── Tags ──────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Nome do ambiente (ex: reference, staging)"
  type        = string
  default     = "reference"
}
