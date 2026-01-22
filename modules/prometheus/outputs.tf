output "instance_name" {
  description = "Name of the created Prometheus instance"
  value       = incus_instance.prometheus.name
}

output "ipv4_address" {
  description = "IPv4 address of the Prometheus instance"
  value       = incus_instance.prometheus.ipv4_address
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.prometheus.name
}

output "instance_status" {
  description = "Status of the created Prometheus instance"
  value       = incus_instance.prometheus.status
}

output "storage_volume_name" {
  description = "Name of the created storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.prometheus_data[0].name : null
}

output "prometheus_endpoint" {
  description = "Prometheus endpoint URL for internal use"
  value       = "http://${var.instance_name}.incus:${var.prometheus_port}"
}

output "tls_enabled" {
  description = "Whether TLS is enabled for this instance (always false for system containers)"
  value       = false
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.prometheus.name
    ipv4_address = incus_instance.prometheus.ipv4_address
  }
}

output "ansible_vars" {
  description = "Variables passed to Ansible for Prometheus configuration"
  sensitive   = true
  value = {
    prometheus_version            = var.prometheus_version
    prometheus_port               = var.prometheus_port
    prometheus_retention_time     = var.retention_time
    prometheus_retention_size     = var.retention_size
    prometheus_config             = var.prometheus_config
    prometheus_alert_rules_base64 = base64encode(var.alert_rules)
    prometheus_has_alert_rules    = var.alert_rules != ""
    incus_metrics_cert            = var.incus_metrics_certificate
    incus_metrics_key             = var.incus_metrics_private_key
    incus_has_metrics_cert        = var.incus_metrics_certificate != ""
  }
}
