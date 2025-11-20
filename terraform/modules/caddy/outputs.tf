output "instance_name" {
  description = "Name of the created Caddy instance"
  value       = incus_instance.caddy.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.caddy.name
}

output "instance_status" {
  description = "Status of the created Caddy instance"
  value       = incus_instance.caddy.status
}
