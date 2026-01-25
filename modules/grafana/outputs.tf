output "instance_name" {
  description = "Name of the created Grafana instance"
  value       = incus_instance.grafana.name
}

output "ipv4_address" {
  description = "IPv4 address of the Grafana instance"
  value       = incus_instance.grafana.ipv4_address
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.grafana.name
}

output "instance_status" {
  description = "Status of the created Grafana instance"
  value       = incus_instance.grafana.status
}

output "storage_volume_name" {
  description = "Name of the created storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.grafana_data[0].name : null
}

output "tls_enabled" {
  description = "Whether TLS is enabled for this instance (always false for system containers)"
  value       = false
}

output "dns_records" {
  description = "DNS records for this Grafana instance (for CoreDNS zone file generation)"
  value = var.domain != "" ? [
    {
      name  = split(".", var.domain)[0] # Extract hostname (e.g., "grafana" from "grafana.accuser.dev")
      type  = "A"
      value = incus_instance.grafana.ipv4_address
      ttl   = 300
    }
  ] : []
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "ansible_vars" {
  description = "Variables to pass to Ansible for Grafana configuration"
  sensitive   = true
  value = {
    grafana_version    = var.grafana_version
    grafana_port       = var.grafana_port
    grafana_domain     = var.domain
    grafana_admin_user = var.admin_user
    # admin_password via env var GRAFANA_ADMIN_PASSWORD at runtime
    grafana_datasources = var.datasources
  }
}

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.grafana.name
    ipv4_address = incus_instance.grafana.ipv4_address
  }
}
