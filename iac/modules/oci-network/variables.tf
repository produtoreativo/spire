variable "compartment_ocid" {
  description = "OCID do compartimento"
  type        = string
}

variable "name_prefix" {
  description = "Prefixo para nomes de recursos"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR block da VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR da subnet pública (Load Balancer)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR da subnet privada (instâncias)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default     = {}
}
