output "instance_name" {
  description = "Name of the created Atlantis instance"
  value       = incus_instance.atlantis.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.atlantis.name
}

output "instance_status" {
  description = "Status of the created Atlantis instance"
  value       = incus_instance.atlantis.status
}

output "storage_volume_name" {
  description = "Name of the created storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.atlantis_data[0].name : null
}

output "webhook_endpoint" {
  description = "Full webhook endpoint URL for GitHub"
  value       = "${var.atlantis_url}/events"
}
