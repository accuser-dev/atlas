# =============================================================================
# Network ACL Module Variables
# =============================================================================

variable "name" {
  description = "Name of the network ACL"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "ACL name must contain only lowercase letters, numbers, and hyphens"
  }
}

variable "description" {
  description = "Description of the network ACL"
  type        = string
  default     = ""
}

variable "project" {
  description = "Incus project (default project if empty)"
  type        = string
  default     = "default"
}

# -----------------------------------------------------------------------------
# Ingress Rules
# -----------------------------------------------------------------------------
# Rules for incoming traffic to instances using this ACL

variable "ingress_rules" {
  description = <<-EOT
    List of ingress (incoming) rules. Each rule is a map with:
    - action: "allow", "drop", or "reject"
    - source: Source address/CIDR, @internal, @external, or instance name
    - destination: Destination address/CIDR (optional)
    - protocol: "tcp", "udp", "icmp4", "icmp6", or empty for all
    - source_port: Source port or range (optional)
    - destination_port: Destination port or range (e.g., "80", "80-443")
    - icmp_type: ICMP type (optional, for ICMP protocol)
    - icmp_code: ICMP code (optional, for ICMP protocol)
    - description: Rule description
    - state: "enabled", "disabled", or "logged"
  EOT
  type = list(object({
    action           = string
    source           = optional(string, "")
    destination      = optional(string, "")
    protocol         = optional(string, "")
    source_port      = optional(string, "")
    destination_port = optional(string, "")
    icmp_type        = optional(string, "")
    icmp_code        = optional(string, "")
    description      = optional(string, "")
    state            = optional(string, "enabled")
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      contains(["allow", "drop", "reject"], rule.action)
    ])
    error_message = "Rule action must be 'allow', 'drop', or 'reject'"
  }

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      contains(["enabled", "disabled", "logged"], rule.state)
    ])
    error_message = "Rule state must be 'enabled', 'disabled', or 'logged'"
  }
}

# -----------------------------------------------------------------------------
# Egress Rules
# -----------------------------------------------------------------------------
# Rules for outgoing traffic from instances using this ACL

variable "egress_rules" {
  description = <<-EOT
    List of egress (outgoing) rules. Each rule is a map with:
    - action: "allow", "drop", or "reject"
    - source: Source address/CIDR (optional)
    - destination: Destination address/CIDR, @internal, @external, or instance name
    - protocol: "tcp", "udp", "icmp4", "icmp6", or empty for all
    - source_port: Source port or range (optional)
    - destination_port: Destination port or range (e.g., "80", "80-443")
    - icmp_type: ICMP type (optional, for ICMP protocol)
    - icmp_code: ICMP code (optional, for ICMP protocol)
    - description: Rule description
    - state: "enabled", "disabled", or "logged"
  EOT
  type = list(object({
    action           = string
    source           = optional(string, "")
    destination      = optional(string, "")
    protocol         = optional(string, "")
    source_port      = optional(string, "")
    destination_port = optional(string, "")
    icmp_type        = optional(string, "")
    icmp_code        = optional(string, "")
    description      = optional(string, "")
    state            = optional(string, "enabled")
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.egress_rules :
      contains(["allow", "drop", "reject"], rule.action)
    ])
    error_message = "Rule action must be 'allow', 'drop', or 'reject'"
  }

  validation {
    condition = alltrue([
      for rule in var.egress_rules :
      contains(["enabled", "disabled", "logged"], rule.state)
    ])
    error_message = "Rule state must be 'enabled', 'disabled', or 'logged'"
  }
}
