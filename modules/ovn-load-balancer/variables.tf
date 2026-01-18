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

  validation {
    condition = alltrue([
      for b in var.backends : can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", b.target_address))
    ])
    error_message = "All backend target_address values must be valid IPv4 addresses."
  }

  validation {
    condition = alltrue([
      for b in var.backends : b.target_port == null || (b.target_port >= 1 && b.target_port <= 65535)
    ])
    error_message = "Backend target_port must be between 1 and 65535 when specified."
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

  validation {
    condition     = alltrue([for p in var.ports : p.listen_port >= 1 && p.listen_port <= 65535])
    error_message = "All listen_port values must be between 1 and 65535."
  }
}

variable "health_check" {
  description = "Health check configuration. When enabled, OVN monitors backend health and removes unhealthy backends from rotation."
  type = object({
    enabled       = optional(bool, false)
    interval      = optional(number, 10)
    timeout       = optional(number, 30)
    failure_count = optional(number, 3)
    success_count = optional(number, 3)
  })
  default = {}

  validation {
    condition     = try(var.health_check.interval, 10) >= 1
    error_message = "health_check.interval must be at least 1 second."
  }

  validation {
    condition     = try(var.health_check.timeout, 30) >= 1
    error_message = "health_check.timeout must be at least 1 second."
  }

  validation {
    condition     = try(var.health_check.failure_count, 3) >= 1
    error_message = "health_check.failure_count must be at least 1."
  }

  validation {
    condition     = try(var.health_check.success_count, 3) >= 1
    error_message = "health_check.success_count must be at least 1."
  }
}
