# =============================================================================
# OVN Configuration Module Outputs
# =============================================================================

output "northbound_connection" {
  description = "Configured OVN northbound connection string"
  value       = var.northbound_connection
}

output "configured" {
  description = "Whether OVN configuration has been applied"
  value       = true
}
