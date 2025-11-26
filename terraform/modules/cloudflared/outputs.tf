output "instance_name" {
  description = "Name of the created cloudflared instance"
  value       = incus_instance.cloudflared.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.cloudflared.name
}

output "instance_status" {
  description = "Status of the created cloudflared instance"
  value       = incus_instance.cloudflared.status
}

output "metrics_endpoint" {
  description = "Metrics endpoint URL for Prometheus scraping"
  value       = "http://${var.instance_name}.incus:${var.metrics_port}"
}
