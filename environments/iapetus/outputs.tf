# =============================================================================
# Network Configuration
# =============================================================================

output "production_network_type" {
  description = "Production network type (bridge or physical)"
  value       = module.base.production_network_type
}

output "production_network_is_physical" {
  description = "Whether production network is physical (direct LAN attachment)"
  value       = module.base.production_network_is_physical
}

# =============================================================================
# Service Configuration
# =============================================================================

output "loki_endpoint" {
  description = "Loki endpoint URL for internal use (configure as Grafana data source)"
  value       = module.loki01.loki_endpoint
}

output "prometheus_endpoint" {
  description = "Prometheus endpoint URL for internal use (configure as Grafana data source)"
  value       = module.prometheus01.prometheus_endpoint
}

output "step_ca_acme_endpoint" {
  description = "step-ca ACME endpoint URL for certificate requests"
  value       = module.step_ca01.acme_endpoint
}

output "step_ca_acme_directory" {
  description = "step-ca ACME directory URL for ACME clients"
  value       = module.step_ca01.acme_directory
}

output "step_ca_fingerprint_command" {
  description = "Command to retrieve the CA fingerprint (run after deployment)"
  value       = module.step_ca01.fingerprint_command
}

output "node_exporter_endpoint" {
  description = "Node Exporter metrics endpoint URL for host monitoring"
  value       = module.node_exporter01.node_exporter_endpoint
}

# =============================================================================
# DNS Configuration
# =============================================================================

output "coredns_dns_endpoint" {
  description = "Internal DNS endpoint using .incus DNS"
  value       = module.coredns01.dns_endpoint
}

output "coredns_ipv4_address" {
  description = "CoreDNS IPv4 address (use this for DHCP DNS server configuration)"
  value       = module.coredns01.ipv4_address
}

output "coredns_external_port" {
  description = "External DNS port on host (bridge mode only, empty if physical mode)"
  value       = module.coredns01.external_dns_port
}

output "coredns_health_endpoint" {
  description = "CoreDNS health check endpoint URL"
  value       = module.coredns01.health_endpoint
}

output "coredns_metrics_endpoint" {
  description = "CoreDNS Prometheus metrics endpoint URL"
  value       = module.coredns01.metrics_endpoint
}

output "coredns_zone_file" {
  description = "Generated DNS zone file content (for debugging)"
  value       = module.coredns01.zone_file_content
}

# =============================================================================
# Cloudflare Tunnel
# =============================================================================

output "cloudflared_metrics_endpoint" {
  description = "Cloudflared metrics endpoint URL (if enabled)"
  value       = length(module.cloudflared01) > 0 ? module.cloudflared01[0].metrics_endpoint : null
}

output "cloudflared_instance_status" {
  description = "Cloudflared instance status (if enabled)"
  value       = length(module.cloudflared01) > 0 ? module.cloudflared01[0].instance_status : null
}

output "incus_metrics_endpoint" {
  description = "Incus metrics endpoint URL being scraped by Prometheus"
  value       = var.enable_incus_metrics ? "https://${var.incus_metrics_address}/1.0/metrics" : null
}

output "incus_metrics_certificate_fingerprint" {
  description = "Fingerprint of the metrics certificate registered with Incus"
  value       = var.enable_incus_metrics ? module.incus_metrics[0].certificate_fingerprint : null
}

output "incus_loki_logging_name" {
  description = "Name of the Incus logging configuration for Loki"
  value       = var.enable_incus_loki ? module.incus_loki[0].logging_name : null
}

output "incus_loki_address" {
  description = "Loki address configured for Incus logging"
  value       = var.enable_incus_loki ? module.incus_loki[0].loki_address : null
}

# GitOps outputs
output "atlantis_webhook_endpoint" {
  description = "Atlantis webhook endpoint URL for GitHub webhooks"
  value       = var.enable_gitops ? module.atlantis01[0].webhook_endpoint : null
}

output "atlantis_instance_status" {
  description = "Atlantis instance status (if enabled)"
  value       = var.enable_gitops ? module.atlantis01[0].instance_status : null
}

