output "instance_name" {
  description = "Name of the created Promtail instance"
  value       = incus_instance.promtail.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.promtail.name
}

output "instance_status" {
  description = "Status of the created Promtail instance"
  value       = incus_instance.promtail.status
}

output "promtail_endpoint" {
  description = "Promtail HTTP API endpoint URL (using .incus DNS)"
  value       = "http://${var.instance_name}.incus:${var.promtail_port}"
}

output "ipv4_address" {
  description = "IPv4 address of the Promtail instance"
  value       = incus_instance.promtail.ipv4_address
}

output "loki_push_url" {
  description = "Configured Loki push URL"
  value       = var.loki_push_url
}
