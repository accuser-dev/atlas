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
  value       = "${var.enable_ssl ? "ssl" : "tcp"}:${var.host_address}:${var.northbound_port}"
}

output "southbound_connection" {
  description = "OVN southbound connection string for chassis nodes (uses host address for cluster-wide access)"
  value       = "${var.enable_ssl ? "ssl" : "tcp"}:${var.host_address}:${var.southbound_port}"
}

output "ssl_enabled" {
  description = "Whether SSL is enabled for OVN database connections"
  value       = var.enable_ssl
}

output "ssl_ca_cert" {
  description = "CA certificate used for SSL connections (for client configuration)"
  value       = var.enable_ssl ? var.ssl_ca_cert : null
  sensitive   = true
}

output "metrics_enabled" {
  description = "Whether Prometheus metrics are enabled"
  value       = var.enable_metrics
}

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint URL"
  value       = var.enable_metrics ? "http://${incus_instance.ovn_central.ipv4_address}:${var.metrics_port}/metrics" : null
}

output "metrics_port" {
  description = "Port for Prometheus metrics"
  value       = var.enable_metrics ? var.metrics_port : null
}

output "northbound_port" {
  description = "OVN northbound database port"
  value       = var.northbound_port
}

output "southbound_port" {
  description = "OVN southbound database port"
  value       = var.southbound_port
}
