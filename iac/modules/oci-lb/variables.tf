variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "subnet_id" { type = string }
variable "instance_ip" { type = string }
variable "nsg_ids" { type = list(string) }
variable "tags" {
  type    = map(string)
  default = {}
}

variable "shape" {
  description = "Shape do Load Balancer (10Mbps é Free Tier)"
  type        = string
  default     = "flexible"
}

variable "min_bandwidth_mbps" {
  type    = number
  default = 10
}

variable "max_bandwidth_mbps" {
  type    = number
  default = 10
}

variable "https_port" {
  type    = number
  default = 443
}

variable "http_port" {
  type    = number
  default = 80
}

# NodePort do Traefik no K3s (padrão 30080 HTTP, 30443 HTTPS)
variable "traefik_http_nodeport" {
  type    = number
  default = 30080
}

variable "traefik_https_nodeport" {
  type    = number
  default = 30443
}
