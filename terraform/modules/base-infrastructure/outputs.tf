# =============================================================================
# Network Outputs
# =============================================================================
# Full resource references for dependency tracking

output "production_network" {
  description = "Production network resource"
  value       = incus_network.production
}

output "production_network_type" {
  description = "Production network type (bridge or physical)"
  value       = var.production_network_type
}

output "production_network_is_physical" {
  description = "Whether production network is physical (direct LAN attachment)"
  value       = var.production_network_type == "physical"
}

output "management_network" {
  description = "Management network resource"
  value       = incus_network.management
}

output "gitops_network" {
  description = "GitOps network resource (null if enable_gitops is false)"
  value       = var.enable_gitops ? incus_network.gitops[0] : null
}

# Convenience output for management network gateway IP
output "management_network_gateway" {
  description = "Management network gateway IP address (for metrics endpoint)"
  value       = split("/", var.management_network_ipv4)[0]
}

# =============================================================================
# Profile Outputs
# =============================================================================
# Full resource references for dependency tracking

output "container_base_profile" {
  description = "Container base profile resource (boot.autorestart only)"
  value       = incus_profile.container_base
}

output "production_network_profile" {
  description = "Production network profile resource (prod NIC on production network)"
  value       = incus_profile.production_network
}

output "management_network_profile" {
  description = "Management network profile resource (mgmt NIC on management network)"
  value       = incus_profile.management_network
}

output "gitops_network_profile" {
  description = "GitOps network profile resource (null if enable_gitops is false)"
  value       = var.enable_gitops ? incus_profile.gitops_network[0] : null
}

# =============================================================================
# External Network Output
# =============================================================================

output "external_network" {
  description = "External network name (typically incusbr0)"
  value       = var.external_network
}
