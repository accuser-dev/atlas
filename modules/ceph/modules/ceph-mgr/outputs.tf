# =============================================================================
# Ceph MGR Submodule Outputs
# =============================================================================

output "instance_name" {
  description = "Name of the MGR instance"
  value       = incus_instance.ceph_mgr.name
}

output "profile_name" {
  description = "Name of the MGR profile"
  value       = incus_profile.ceph_mgr.name
}

output "instance_status" {
  description = "Status of the MGR instance"
  value       = incus_instance.ceph_mgr.status
}

output "ipv4_address" {
  description = "IPv4 address of the MGR instance"
  value       = incus_instance.ceph_mgr.ipv4_address
}

output "mgr_id" {
  description = "MGR daemon ID"
  value       = var.mgr_id
}

output "dashboard_endpoint" {
  description = "Dashboard endpoint (if enabled)"
  value       = var.enable_dashboard ? "https://${incus_instance.ceph_mgr.ipv4_address}:${var.dashboard_port}" : null
}

output "prometheus_endpoint" {
  description = "Prometheus metrics endpoint (if enabled)"
  value       = var.enable_prometheus ? "http://${incus_instance.ceph_mgr.ipv4_address}:${var.prometheus_port}" : null
}
