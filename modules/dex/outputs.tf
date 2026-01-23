output "instance_name" {
  description = "Name of the Dex container instance"
  value       = incus_instance.dex.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.dex.name
}

output "instance_status" {
  description = "Status of the Dex container instance"
  value       = incus_instance.dex.status
}

output "ipv4_address" {
  description = "IPv4 address of the Dex instance"
  value       = incus_instance.dex.ipv4_address
}

output "issuer_url" {
  description = "The OIDC issuer URL for clients to use"
  value       = var.issuer_url
}

output "http_endpoint" {
  description = "HTTP endpoint URL for Dex"
  value       = "http://${incus_instance.dex.name}.incus:${var.http_port}"
}

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint URL"
  value       = "http://${incus_instance.dex.name}.incus:${var.metrics_port}/metrics"
}

output "discovery_url" {
  description = "OIDC discovery endpoint (well-known configuration)"
  value       = "${var.issuer_url}/.well-known/openid-configuration"
}

output "dns_records" {
  description = "DNS records for this Dex instance (for CoreDNS zone file generation)"
  value = [
    {
      name  = "dex"
      type  = "A"
      value = incus_instance.dex.ipv4_address
      ttl   = 300
    }
  ]
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "ansible_vars" {
  description = "Variables to pass to Ansible for Dex configuration"
  sensitive   = true
  value = {
    dex_version       = var.dex_version
    dex_http_port     = var.http_port
    dex_grpc_port     = var.grpc_port
    dex_metrics_port  = var.metrics_port
    dex_issuer_url    = var.issuer_url
    dex_config_base64 = base64encode(local.dex_config)
    dex_has_config    = true
    # GitHub credentials via env vars: DEX_GITHUB_CLIENT_ID, DEX_GITHUB_CLIENT_SECRET
  }
}

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.dex.name
    ipv4_address = incus_instance.dex.ipv4_address
  }
}
