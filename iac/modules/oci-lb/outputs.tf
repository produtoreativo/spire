output "public_ip" {
  value = oci_load_balancer_load_balancer.this.ip_address_details[0].ip_address
}

output "lb_id" {
  value = oci_load_balancer_load_balancer.this.id
}
