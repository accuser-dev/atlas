# =============================================================================
# Instance Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the Prefect container instance"
  value       = incus_instance.prefect.name
}

output "instance_status" {
  description = "Status of the Prefect container"
  value       = incus_instance.prefect.status
}

output "ipv4_address" {
  description = "IPv4 address of the Prefect container"
  value       = incus_instance.prefect.ipv4_address
}

output "profile_name" {
  description = "Name of the created Incus profile"
  value       = incus_profile.prefect.name
}

# =============================================================================
# Storage Outputs
# =============================================================================

output "storage_volume_name" {
  description = "Name of the data storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.prefect_data[0].name : null
}

# =============================================================================
# Service Endpoints
# =============================================================================

output "prefect_endpoint" {
  description = "Prefect server UI/API endpoint"
  value       = "http://${incus_instance.prefect.name}.incus:${var.prefect_port}"
}

output "prefect_api_url" {
  description = "Prefect API URL for worker/agent configuration"
  value       = "http://${incus_instance.prefect.name}.incus:${var.prefect_port}/api"
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.prefect.name
    ipv4_address = incus_instance.prefect.ipv4_address
  }
}

output "ansible_vars" {
  description = "Variables passed to Ansible for Prefect configuration"
  sensitive   = true
  value = {
    prefect_port          = var.prefect_port
    prefect_database_host = var.database_host
    prefect_database_port = var.database_port
    prefect_database_name = var.database_name
    prefect_database_user = var.database_user
    # Note: database_password passed via environment variable at runtime
  }
}
