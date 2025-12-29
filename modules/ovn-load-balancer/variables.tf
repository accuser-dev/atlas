# =============================================================================
# OVN Load Balancer Module Variables
# =============================================================================

variable "network_name" {
  description = "Name of the OVN network to attach the load balancer to"
  type        = string
}

variable "listen_address" {
  description = "VIP address for the load balancer (must be in the uplink's ipv4.ovn.ranges)"
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.listen_address))
    error_message = "listen_address must be a valid IPv4 address."
  }
}

variable "description" {
  description = "Description for the load balancer"
  type        = string
  default     = ""
}

variable "backends" {
  description = "List of backend targets for the load balancer. Each backend has a name, target IP, and optional port."
  type = list(object({
    name           = string
    description    = optional(string, "")
    target_address = string
    target_port    = optional(number)
  }))

  validation {
    condition     = length(var.backends) > 0
    error_message = "At least one backend must be specified."
  }
}

variable "ports" {
  description = "List of port mappings for the load balancer. Each port specifies listen port and which backends to target."
  type = list(object({
    description     = optional(string, "")
    protocol        = optional(string, "tcp")
    listen_port     = number
    target_backends = optional(list(string))
  }))

  validation {
    condition     = length(var.ports) > 0
    error_message = "At least one port mapping must be specified."
  }

  validation {
    condition     = alltrue([for p in var.ports : contains(["tcp", "udp"], p.protocol)])
    error_message = "Protocol must be 'tcp' or 'udp'."
  }
}
