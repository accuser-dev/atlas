# =============================================================================
# Ceph OSD Submodule Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the OSD instance"
  value       = incus_instance.ceph_osd.name
}

output "profile_name" {
  description = "Name of the OSD profile"
  value       = incus_profile.ceph_osd.name
}

output "instance_status" {
  description = "Status of the OSD instance"
  value       = incus_instance.ceph_osd.status
}

output "ipv4_address" {
  description = "IPv4 address of the OSD instance"
  value       = incus_instance.ceph_osd.ipv4_address
}

output "target_node" {
  description = "Cluster node this OSD is pinned to"
  value       = var.target_node
}

output "osd_block_device" {
  description = "Block device used by this OSD"
  value       = var.osd_block_device
}
