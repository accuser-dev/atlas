# =============================================================================
# Network Outputs
# =============================================================================
# Full resource references for dependency tracking

output "development_network" {
  description = "Development network resource"
  value       = incus_network.development
}

output "testing_network" {
  description = "Testing network resource"
  value       = incus_network.testing
}

output "staging_network" {
  description = "Staging network resource"
  value       = incus_network.staging
}

output "production_network" {
  description = "Production network resource"
  value       = incus_network.production
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

output "docker_base_profile" {
  description = "Docker base profile resource (boot.autorestart, root disk)"
  value       = incus_profile.docker_base
}

output "management_network_profile" {
  description = "Management network profile resource (mgmt NIC on management network)"
  value       = incus_profile.management_network
}

output "production_network_profile" {
  description = "Production network profile resource (prod NIC on production network)"
  value       = incus_profile.production_network
}

output "development_network_profile" {
  description = "Development network profile resource (dev NIC on development network)"
  value       = incus_profile.development_network
}

output "testing_network_profile" {
  description = "Testing network profile resource (test NIC on testing network)"
  value       = incus_profile.testing_network
}

output "staging_network_profile" {
  description = "Staging network profile resource (stage NIC on staging network)"
  value       = incus_profile.staging_network
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
