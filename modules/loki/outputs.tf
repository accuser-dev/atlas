output "instance_name" {
  description = "Name of the created Loki instance"
  value       = incus_instance.loki.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.loki.name
}

output "instance_status" {
  description = "Status of the created Loki instance"
  value       = incus_instance.loki.status
}

output "storage_volume_name" {
  description = "Name of the created storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.loki_data[0].name : null
}

output "loki_endpoint" {
  description = "Loki endpoint URL for internal use"
  value       = "http://${var.instance_name}.incus:${var.loki_port}"
}
