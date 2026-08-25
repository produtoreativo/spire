output "lb_nsg_id" {
  value = oci_core_network_security_group.lb.id
}

output "instance_nsg_id" {
  value = oci_core_network_security_group.instance.id
}
