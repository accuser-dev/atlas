# =============================================================================
# Network ACL Module Outputs
# =============================================================================

output "name" {
  description = "Name of the created ACL"
  value       = incus_network_acl.this.name
}

output "ingress_rule_count" {
  description = "Number of ingress rules"
  value       = length(var.ingress_rules)
}

output "egress_rule_count" {
  description = "Number of egress rules"
  value       = length(var.egress_rules)
}
