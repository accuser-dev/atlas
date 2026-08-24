# =============================================================================
# Incus OIDC Configuration Module Outputs
# =============================================================================

output "issuer" {
  description = "Configured OIDC issuer URL"
  value       = var.issuer
}

output "client_id" {
  description = "Configured OIDC client ID"
  value       = var.client_id
}
