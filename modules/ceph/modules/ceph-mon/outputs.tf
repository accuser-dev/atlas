# =============================================================================
# Ceph MON Submodule Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the MON instance"
  value       = incus_instance.ceph_mon.name
}

output "profile_name" {
  description = "Name of the MON profile"
  value       = incus_profile.ceph_mon.name
}

output "instance_status" {
  description = "Status of the MON instance"
  value       = incus_instance.ceph_mon.status
}

output "ipv4_address" {
  description = "IPv4 address of the MON instance"
  value       = incus_instance.ceph_mon.ipv4_address
}

output "mon_id" {
  description = "MON daemon ID"
  value       = var.mon_id
}

output "mon_endpoint" {
  description = "MON endpoint (IP:port)"
  value       = "${incus_instance.ceph_mon.ipv4_address}:${var.mon_port}"
}

output "storage_volume_name" {
  description = "Name of the data storage volume"
  value       = var.enable_data_persistence ? incus_storage_volume.mon_data[0].name : null
}

output "is_bootstrap" {
  description = "Whether this is the bootstrap MON"
  value       = var.is_bootstrap
}
