# =============================================================================
# OVN Central Module Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the OVN Central container"
  value       = incus_instance.ovn_central.name
}

output "ipv4_address" {
  description = "IPv4 address of the OVN Central container"
  value       = incus_instance.ovn_central.ipv4_address
}

output "ipv6_address" {
  description = "IPv6 address of the OVN Central container"
  value       = incus_instance.ovn_central.ipv6_address
}

output "northbound_connection" {
  description = "OVN northbound connection string for Incus configuration (uses host address for cluster-wide access)"
  value       = "tcp:${var.host_address}:${var.northbound_port}"
}

output "southbound_connection" {
  description = "OVN southbound connection string for chassis nodes (uses host address for cluster-wide access)"
  value       = "tcp:${var.host_address}:${var.southbound_port}"
}

output "northbound_port" {
  description = "OVN northbound database port"
  value       = var.northbound_port
}

output "southbound_port" {
  description = "OVN southbound database port"
  value       = var.southbound_port
}
