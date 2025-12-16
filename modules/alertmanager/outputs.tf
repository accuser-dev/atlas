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
