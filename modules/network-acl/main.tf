# =============================================================================
# Network ACL Module
# =============================================================================
# Creates Incus network ACLs for microsegmentation.
# Supports OVN networks with ingress/egress rules.
#
# ACL states:
# - "enabled": Rule is active and enforced
# - "disabled": Rule is inactive
# - "logged": Rule matches are logged but traffic is allowed (for testing)

resource "incus_network_acl" "this" {
  name        = var.name
  description = var.description
  project     = var.project

  egress  = var.egress_rules
  ingress = var.ingress_rules
}
