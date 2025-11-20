output "instance_name" {
  description = "Name of the created Prometheus instance"
  value       = incus_instance.prometheus.name
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
