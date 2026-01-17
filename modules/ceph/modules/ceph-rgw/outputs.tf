# =============================================================================
# Ceph RGW Submodule Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the RGW instance"
  value       = incus_instance.ceph_rgw.name
}

output "profile_name" {
  description = "Name of the RGW profile"
  value       = incus_profile.ceph_rgw.name
}

output "instance_status" {
  description = "Status of the RGW instance"
  value       = incus_instance.ceph_rgw.status
}

output "ipv4_address" {
  description = "IPv4 address of the RGW instance"
  value       = incus_instance.ceph_rgw.ipv4_address
}

output "rgw_id" {
  description = "RGW daemon ID"
  value       = var.rgw_id
}

output "s3_endpoint" {
  description = "S3 API endpoint"
  value       = "http://${incus_instance.ceph_rgw.ipv4_address}:${var.rgw_port}"
}

output "rgw_port" {
  description = "RGW port"
  value       = var.rgw_port
}
