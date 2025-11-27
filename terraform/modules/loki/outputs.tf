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
  description = "Loki endpoint URL for internal use (using .incus DNS)"
  value       = "${var.enable_tls ? "https" : "http"}://${var.instance_name}.incus:${var.loki_port}"
}

output "loki_endpoint_ip" {
  description = "Loki endpoint URL using IP address (for host-level access)"
  value       = "${var.enable_tls ? "https" : "http"}://${incus_instance.loki.ipv4_address}:${var.loki_port}"
}

output "ipv4_address" {
  description = "IPv4 address of the Loki instance"
  value       = incus_instance.loki.ipv4_address
}

output "tls_enabled" {
  description = "Whether TLS is enabled for this instance"
  value       = var.enable_tls
}
