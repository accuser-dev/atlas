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

output "caddy_config_block" {
  description = "Caddyfile configuration block for this Atlantis instance"
  value = var.domain != "" ? templatefile("${path.module}/templates/caddyfile.tftpl", {
    domain               = var.domain
    allowed_ip_range     = var.allowed_ip_range
    instance_name        = var.instance_name
    port                 = var.atlantis_port
    enable_rate_limiting = var.enable_rate_limiting
    rate_limit_requests  = var.rate_limit_requests
    rate_limit_window    = var.rate_limit_window
  }) : ""
}
