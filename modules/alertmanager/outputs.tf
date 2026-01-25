output "instance_name" {
  description = "Name of the created Alertmanager instance"
  value       = incus_instance.alertmanager.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.alertmanager.name
}

output "instance_status" {
  description = "Status of the created Alertmanager instance"
  value       = incus_instance.alertmanager.status
}

output "storage_volume_name" {
  description = "Name of the created storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.alertmanager_data[0].name : null
}

output "alertmanager_endpoint" {
  description = "Alertmanager endpoint URL for internal use"
  value       = "${var.enable_tls ? "https" : "http"}://${var.instance_name}.incus:${var.alertmanager_port}"
}

output "tls_enabled" {
  description = "Whether TLS is enabled for this instance"
  value       = var.enable_tls
}

output "ipv4_address" {
  description = "IPv4 address of the Alertmanager container"
  value       = incus_instance.alertmanager.ipv4_address
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.alertmanager.name
    ipv4_address = incus_instance.alertmanager.ipv4_address
  }
}

output "ansible_vars" {
  description = "Variables passed to Ansible for Alertmanager configuration"
  sensitive   = true
  value = {
    alertmanager_version       = var.alertmanager_version
    alertmanager_port          = var.alertmanager_port
    alertmanager_config_base64 = base64encode(local.alertmanager_config)
    alertmanager_has_config    = true
    alertmanager_enable_tls    = var.enable_tls
    stepca_url                 = var.stepca_url
    stepca_fingerprint         = var.stepca_fingerprint
    cert_duration              = var.cert_duration
    step_version               = var.step_version
  }
}
