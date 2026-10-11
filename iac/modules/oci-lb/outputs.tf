output "public_ip" {
  description = "IP público do Load Balancer"
  value       = try(oci_load_balancer_load_balancer.this.ip_address_details[0].ip_address, null)
}

output "lb_id" {
  description = "OCID do Load Balancer"
  value       = oci_load_balancer_load_balancer.this.id
}
