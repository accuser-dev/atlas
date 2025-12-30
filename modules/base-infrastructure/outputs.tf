# =============================================================================
# Network Outputs
# =============================================================================
# Full resource references for dependency tracking

output "production_network" {
  description = "Production network resource (bridge/physical backend)"
  value       = var.network_backend != "ovn" ? incus_network.production[0] : null
}

output "production_network_type" {
  description = "Production network type (bridge, physical, or ovn)"
  value       = var.network_backend == "ovn" ? "ovn" : var.production_network_type
}

output "production_network_is_physical" {
  description = "Whether production network is physical (direct LAN attachment)"
  value       = var.network_backend != "ovn" && var.production_network_type == "physical"
}

output "management_network" {
  description = "Management network resource (bridge backend)"
  value       = var.network_backend != "ovn" && !var.management_network_external ? incus_network.management[0] : null
}

output "gitops_network" {
  description = "GitOps network resource (null if enable_gitops is false or using OVN)"
  value       = var.enable_gitops && var.network_backend != "ovn" ? incus_network.gitops[0] : null
}

# =============================================================================
# OVN Network Outputs
# =============================================================================

output "ovn_production_network" {
  description = "OVN production network resource (null if not using OVN backend or using external)"
  value = (
    var.network_backend == "ovn"
    ? (var.ovn_production_external
      ? data.incus_network.ovn_production_external[0]
      : incus_network.ovn_production[0])
    : null
  )
}

output "ovn_management_network" {
  description = "OVN management network resource (null if not using OVN backend)"
  value       = var.network_backend == "ovn" ? incus_network.ovn_management[0] : null
}

output "ovn_gitops_network" {
  description = "OVN GitOps network resource (null if not using OVN or gitops disabled)"
  value       = var.network_backend == "ovn" && var.enable_gitops ? incus_network.ovn_gitops[0] : null
}

# =============================================================================
# Network Name Outputs (Backend-Agnostic)
# =============================================================================
# Use these for service modules - they return the correct network name regardless of backend

output "production_network_name" {
  description = "Production network name (works with any backend)"
  value       = local.production_network_name
}

output "management_network_name" {
  description = "Management network name (works with any backend)"
  value       = local.management_network_name
}

output "gitops_network_name" {
  description = "GitOps network name (null if gitops disabled)"
  value       = local.gitops_network_name
}

output "network_backend" {
  description = "Active network backend (bridge or ovn)"
  value       = var.network_backend
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
