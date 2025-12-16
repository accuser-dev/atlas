output "instance_name" {
  description = "Name of the CoreDNS container instance"
  value       = incus_instance.coredns.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.coredns.name
}

output "instance_status" {
  description = "Status of the CoreDNS container instance"
  value       = incus_instance.coredns.status
}

output "dns_endpoint" {
  description = "Internal DNS endpoint using .incus DNS"
  value       = "${incus_instance.coredns.name}.incus:${var.dns_port}"
}

output "ipv4_address" {
  description = "IPv4 address of the CoreDNS instance (use this for DHCP DNS server configuration)"
  value       = incus_instance.coredns.ipv4_address
}

output "health_endpoint" {
  description = "Health check endpoint URL"
  value       = "http://${incus_instance.coredns.name}.incus:${var.health_port}/health"
}

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint URL"
  value       = "http://${incus_instance.coredns.name}.incus:9153/metrics"
}

output "external_dns_port" {
  description = "Host port for external DNS access (empty if external access disabled)"
  value       = var.enable_external_access ? var.external_dns_port : ""
}

output "external_access_enabled" {
  description = "Whether external access is enabled via proxy devices"
  value       = var.enable_external_access
}

output "zone_file_content" {
  description = "Generated zone file content (for debugging)"
  value       = local.zone_file_content
}

output "domain" {
  description = "The domain this CoreDNS instance is authoritative for"
  value       = var.domain
}
