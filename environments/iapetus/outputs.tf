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

output "loki_external_port" {
  description = "External port for Loki access via proxy device (use http://<host-ip>:3100 for cross-environment log shipping)"
  value       = module.loki01.external_port
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

# =============================================================================
# OIDC / Authorization
# =============================================================================

output "dex_issuer_url" {
  description = "Dex OIDC issuer URL for client configuration"
  value       = var.enable_oidc ? module.dex01[0].issuer_url : null
}

output "dex_discovery_url" {
  description = "Dex OIDC discovery endpoint URL"
  value       = var.enable_oidc ? module.dex01[0].discovery_url : null
}

output "dex_http_endpoint" {
  description = "Dex HTTP endpoint (internal)"
  value       = var.enable_oidc ? module.dex01[0].http_endpoint : null
}

output "dex_metrics_endpoint" {
  description = "Dex Prometheus metrics endpoint URL"
  value       = var.enable_oidc ? module.dex01[0].metrics_endpoint : null
}

output "openfga_api_url" {
  description = "OpenFGA API URL for Incus configuration (set as openfga.api.url)"
  value       = var.enable_oidc ? module.openfga01[0].api_url : null
}

output "openfga_http_endpoint" {
  description = "OpenFGA HTTP endpoint (internal)"
  value       = var.enable_oidc ? module.openfga01[0].http_endpoint : null
}

output "openfga_metrics_endpoint" {
  description = "OpenFGA Prometheus metrics endpoint URL"
  value       = var.enable_oidc ? module.openfga01[0].metrics_endpoint : null
}

output "incus_oidc_config" {
  description = "Incus OIDC configuration commands (run after deployment)"
  value = var.enable_oidc ? join("\n", [
    "# Configure Incus to use OIDC authentication:",
    "incus config set oidc.issuer ${module.dex01[0].issuer_url}",
    "incus config set oidc.client.id incus",
    "",
    "# Configure Incus to use OpenFGA authorization:",
    "incus config set openfga.api.url ${module.openfga01[0].api_url}",
    "incus config set openfga.api.token <your-preshared-key>"
  ]) : null
}

# =============================================================================
# HAProxy Load Balancer
# =============================================================================

output "haproxy_ipv4_address" {
  description = "HAProxy IPv4 address"
  value       = var.enable_haproxy ? module.haproxy01[0].ipv4_address : null
}

output "haproxy_stats_endpoint" {
  description = "HAProxy stats endpoint URL"
  value       = var.enable_haproxy ? module.haproxy01[0].stats_endpoint : null
}

# =============================================================================
# Managed Resources (for Makefile dynamic discovery)
# =============================================================================
# Maps Incus resource names to their Terraform state paths
# Used by import/clean-incus targets to avoid hardcoded resource lists

output "managed_resources" {
  description = "Resource mappings for Makefile discovery (Incus name -> Terraform path)"
  value = {
    # Profiles: Map Incus profile name -> Terraform import path
    profiles = merge(
      { "grafana" = "module.grafana01.incus_profile.grafana" },
      { "loki" = "module.loki01.incus_profile.loki" },
      { "prometheus" = "module.prometheus01.incus_profile.prometheus" },
      { "step-ca" = "module.step_ca01.incus_profile.step_ca" },
      { "coredns" = "module.coredns01.incus_profile.coredns" },
      var.cloudflared_tunnel_token != "" ? { "cloudflared" = "module.cloudflared01[0].incus_profile.cloudflared" } : {},
      var.enable_gitops ? { "atlantis" = "module.atlantis01[0].incus_profile.atlantis" } : {},
      var.enable_oidc ? { "dex" = "module.dex01[0].incus_profile.dex" } : {},
      var.enable_oidc ? { "openfga" = "module.openfga01[0].incus_profile.openfga" } : {},
      var.enable_haproxy ? { "haproxy" = "module.haproxy01[0].incus_profile.haproxy" } : {},
    )

    # Instances: Map Incus instance name -> Terraform import path
    instances = merge(
      { "grafana01" = "module.grafana01.incus_instance.grafana" },
      { "loki01" = "module.loki01.incus_instance.loki" },
      { "prometheus01" = "module.prometheus01.incus_instance.prometheus" },
      { "step-ca01" = "module.step_ca01.incus_instance.step_ca" },
      { "coredns01" = "module.coredns01.incus_instance.coredns" },
      var.cloudflared_tunnel_token != "" ? { "cloudflared01" = "module.cloudflared01[0].incus_instance.cloudflared" } : {},
      var.enable_gitops ? { "atlantis01" = "module.atlantis01[0].incus_instance.atlantis" } : {},
      var.enable_oidc ? { "dex01" = "module.dex01[0].incus_instance.dex" } : {},
      var.enable_oidc ? { "openfga01" = "module.openfga01[0].incus_instance.openfga" } : {},
      var.enable_haproxy ? { "haproxy01" = "module.haproxy01[0].incus_instance.haproxy" } : {},
    )

    # Volumes: Map Incus volume name -> Terraform import path
    volumes = merge(
      { "grafana01-data" = "module.grafana01.incus_storage_volume.grafana_data[0]" },
      { "loki01-data" = "module.loki01.incus_storage_volume.loki_data[0]" },
      { "prometheus01-data" = "module.prometheus01.incus_storage_volume.prometheus_data[0]" },
      { "step-ca01-data" = "module.step_ca01.incus_storage_volume.step_ca_data[0]" },
      var.enable_gitops ? { "atlantis01-data" = "module.atlantis01[0].incus_storage_volume.atlantis_data[0]" } : {},
      var.enable_oidc ? { "dex01-data" = "module.dex01[0].incus_storage_volume.dex_data[0]" } : {},
      var.enable_oidc ? { "openfga01-data" = "module.openfga01[0].incus_storage_volume.openfga_data[0]" } : {},
    )

    # Networks: Map network name -> Terraform import path
    networks = {
      "production" = "module.base.incus_network.production[0]"
      "management" = "module.base.incus_network.management[0]"
    }
  }
}

