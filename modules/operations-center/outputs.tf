# =============================================================================
# Instance Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the Operations Center VM instance"
  value       = incus_instance.operations_center.name
}

output "instance_status" {
  description = "Status of the Operations Center VM"
  value       = incus_instance.operations_center.status
}

output "ipv4_address" {
  description = "IPv4 address of the Operations Center VM"
  value       = incus_instance.operations_center.ipv4_address
}

output "profile_name" {
  description = "Name of the created Incus profile"
  value       = incus_profile.operations_center.name
}

# =============================================================================
# Connection Outputs
# =============================================================================

output "web_endpoint" {
  description = "Operations Center web UI / API endpoint (TLS client cert auth required). Null until the VM has booted its own OS and acquired an address - it has neither while stopped or mid-install."
  value       = incus_instance.operations_center.ipv4_address != null ? "https://${incus_instance.operations_center.ipv4_address}:8443" : null
}

# =============================================================================
# Ansible Integration Outputs
# =============================================================================
# IncusOS is immutable and configured entirely via its install-time seed, not
# Ansible - this module intentionally has no `ansible_vars` output and should
# not be wired into ansible/inventory/terraform.py.

output "instance_info" {
  description = "Instance information for inventory/discovery purposes"
  value = {
    name         = incus_instance.operations_center.name
    ipv4_address = incus_instance.operations_center.ipv4_address
  }
}
