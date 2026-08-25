output "vcn_id" {
  description = "OCID da VCN"
  value       = oci_core_vcn.this.id
}

output "public_subnet_id" {
  description = "OCID da subnet pública (Load Balancer)"
  value       = oci_core_subnet.public.id
}

output "private_subnet_id" {
  description = "OCID da subnet privada (instâncias)"
  value       = oci_core_subnet.private.id
}
