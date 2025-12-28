output "instance_name" {
  description = "Name of the HAProxy container instance"
  value       = incus_instance.haproxy.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.haproxy.name
}

output "instance_status" {
  description = "Status of the HAProxy container instance"
  value       = incus_instance.haproxy.status
}

output "ipv4_address" {
  description = "IPv4 address of the HAProxy instance"
  value       = incus_instance.haproxy.ipv4_address
}

output "stats_endpoint" {
  description = "HAProxy stats endpoint URL"
  value       = "http://${incus_instance.haproxy.name}.incus:${var.stats_port}/stats"
}

output "stats_port" {
  description = "HAProxy stats port"
  value       = var.stats_port
}
