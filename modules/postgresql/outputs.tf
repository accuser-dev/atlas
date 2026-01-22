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

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.postgresql.name
    ipv4_address = incus_instance.postgresql.ipv4_address
  }
}

output "ansible_vars" {
  description = "Variables passed to Ansible for PostgreSQL configuration"
  sensitive   = true
  value = {
    postgresql_port              = var.postgresql_port
    postgresql_admin_password    = var.admin_password
    postgresql_databases         = var.databases
    postgresql_users             = var.users
    postgresql_allowed_networks  = var.allowed_networks
    postgresql_config            = var.postgresql_config
    postgresql_enable_metrics    = var.enable_metrics
    postgresql_metrics_port      = var.metrics_port
    postgres_exporter_version    = var.postgres_exporter_version
  }
}
