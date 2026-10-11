variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "availability_domain" { type = string }
variable "fault_domain" {
  type    = string
  default = ""
}
variable "image_id" { type = string }
variable "subnet_id" { type = string }
variable "nsg_ids" { type = list(string) }
variable "ssh_public_key" {
  type      = string
  sensitive = true
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  type    = number
  default = 4
}

variable "memory_gb" {
  type    = number
  default = 24
}

variable "boot_volume_size_gb" {
  description = "Tamanho do boot volume em GB"
  type        = number
  default     = 50
}
