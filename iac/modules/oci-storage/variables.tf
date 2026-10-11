variable "compartment_ocid" { type = string }
variable "namespace" { type = string }
variable "bucket_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "versioning" {
  description = "Habilitar versionamento de objetos"
  type        = string
  default     = "Enabled"
}
