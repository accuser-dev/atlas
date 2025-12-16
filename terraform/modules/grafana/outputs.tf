output "instance_name" {
  description = "Name of the created Grafana instance"
  value       = incus_instance.grafana.name
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

output "caddy_config_block" {
  description = "Caddyfile configuration block for this Grafana instance"
  value = var.domain != "" ? templatefile("${path.module}/templates/caddyfile.tftpl", {
    domain                    = var.domain
    allowed_ip_range          = var.allowed_ip_range
    instance_name             = var.instance_name
    port                      = var.grafana_port
    backend_tls               = false # System containers don't use TLS
    enable_rate_limiting      = var.enable_rate_limiting
    rate_limit_requests       = var.rate_limit_requests
    rate_limit_window         = var.rate_limit_window
    login_rate_limit_requests = var.login_rate_limit_requests
    login_rate_limit_window   = var.login_rate_limit_window
  }) : ""
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
