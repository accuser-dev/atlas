# =============================================================================
# OVN Load Balancer Outputs
# =============================================================================

output "listen_address" {
  description = "VIP address of the load balancer"
  value       = incus_network_lb.lb.listen_address
}

output "network" {
  description = "Network the load balancer is attached to"
  value       = incus_network_lb.lb.network
}

output "backends" {
  description = "Configured backends for the load balancer"
  value       = var.backends
}

output "ports" {
  description = "Configured port mappings for the load balancer"
  value       = var.ports
}
