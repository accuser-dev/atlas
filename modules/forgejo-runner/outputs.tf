# =============================================================================
# Instance Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the Forgejo runner container instance"
  value       = incus_instance.forgejo_runner.name
}

output "instance_status" {
  description = "Status of the Forgejo runner container"
  value       = incus_instance.forgejo_runner.status
}

output "ipv4_address" {
  description = "IPv4 address of the Forgejo runner container"
  value       = incus_instance.forgejo_runner.ipv4_address
}

output "profile_name" {
  description = "Name of the created Incus profile"
  value       = incus_profile.forgejo_runner.name
}

# =============================================================================
# Storage Outputs
# =============================================================================

output "storage_volume_name" {
  description = "Name of the data storage volume (if enabled)"
  value       = var.enable_data_persistence ? incus_storage_volume.forgejo_runner_data[0].name : null
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================

output "ansible_vars" {
  description = "Variables to pass to Ansible for runner configuration"
  value = {
    forgejo_url             = var.forgejo_url
    forgejo_runner_labels   = var.runner_labels
    forgejo_runner_insecure = var.runner_insecure
  }
}

output "instance_info" {
  description = "Instance information for Ansible inventory"
  value = {
    name         = incus_instance.forgejo_runner.name
    ipv4_address = incus_instance.forgejo_runner.ipv4_address
  }
}
