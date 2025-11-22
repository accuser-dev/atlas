output "instance_name" {
  description = "Name of the created Grafana instance"
  value       = incus_instance.grafana.name
}

output "profile_name" {
  description = "Name of the created profile"
  value       = incus_profile.grafana.name
}

output "instance_status" {
  description = "Status of the created Grafana instance"
  value       = incus_instance.grafana.status
}

output "storage_volume_name" {
  description = "Name of the created storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.grafana_data[0].name : null
}

output "caddy_config_block" {
  description = "Caddyfile configuration block for this Grafana instance"
  value = var.domain != "" ? templatefile("${path.module}/templates/caddyfile.tftpl", {
    domain           = var.domain
    allowed_ip_range = var.allowed_ip_range
    instance_name    = var.instance_name
    port             = var.grafana_port
  }) : ""
}
