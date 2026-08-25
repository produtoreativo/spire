variable "compartment_ocid" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "vcn_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs permitidos para SSH (restringir ao IP do operador)"
  type        = list(string)
  default     = []
}
