# =============================================================================
# Instance Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the PostgreSQL container instance"
  value       = incus_instance.postgresql.name
}

output "instance_status" {
  description = "Status of the PostgreSQL container"
  value       = incus_instance.postgresql.status
}

output "ipv4_address" {
  description = "IPv4 address of the PostgreSQL container"
  value       = incus_instance.postgresql.ipv4_address
}

output "profile_name" {
  description = "Name of the created Incus profile"
  value       = incus_profile.postgresql.name
}

# =============================================================================
# Storage Outputs
# =============================================================================

output "storage_volume_name" {
  description = "Name of the data storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.postgresql_data[0].name : null
}

# =============================================================================
# Connection Outputs
# =============================================================================

output "postgresql_host" {
  description = "PostgreSQL host address"
  value       = incus_instance.postgresql.ipv4_address
}

output "postgresql_port" {
  description = "PostgreSQL port"
  value       = var.postgresql_port
}

output "postgresql_endpoint" {
  description = "PostgreSQL connection endpoint"
  value       = "postgresql://${incus_instance.postgresql.ipv4_address}:${var.postgresql_port}"
}

output "postgresql_internal_endpoint" {
  description = "PostgreSQL endpoint using Incus DNS name"
  value       = "postgresql://${incus_instance.postgresql.name}.incus:${var.postgresql_port}"
}

# =============================================================================
# Metrics Outputs
# =============================================================================

output "metrics_endpoint" {
  description = "Prometheus metrics endpoint (if enabled)"
  value       = var.enable_metrics ? "http://${incus_instance.postgresql.name}.incus:${var.metrics_port}/metrics" : null
}

output "metrics_port" {
  description = "Prometheus metrics port (if enabled)"
  value       = var.enable_metrics ? var.metrics_port : null
}
