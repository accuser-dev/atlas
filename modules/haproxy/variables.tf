# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the HAProxy container instance"
  type        = string
  default     = "haproxy01"
}

variable "profile_name" {
  description = "Name of the Incus profile to create for HAProxy"
  type        = string
  default     = "haproxy"
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "images:debian/trixie/cloud"
}

variable "storage_pool" {
  description = "Storage pool to use for the container"
  type        = string
  default     = "local"
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profile and network profile)"
  type        = list(string)
  default     = []
}

# =============================================================================
# Network Configuration
# =============================================================================

variable "ipv4_address" {
  description = "Static IPv4 address for the container (e.g., '10.10.0.10'). Leave empty for DHCP."
  type        = string
  default     = ""
}

variable "network_name" {
  description = "Name of the network to attach for static IP configuration. Required when ipv4_address is set."
  type        = string
  default     = ""
}

# =============================================================================
# Resource Limits
# =============================================================================

variable "cpu_limit" {
  description = "CPU limit for the container (e.g., '1' or '2')"
  type        = string
  default     = "1"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be a number between 1 and 64."
  }
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g., '256MB' or '512MB')"
  type        = string
  default     = "256MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '256MB' or '1GB'."
  }
}

variable "root_disk_size" {
  description = "Size limit for the root disk (e.g., '1GB')"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '512MB' or '1GB'."
  }
}

# =============================================================================
# HAProxy Stats Configuration
# =============================================================================

variable "stats_port" {
  description = "Port for HAProxy stats interface"
  type        = number
  default     = 8404

  validation {
    condition     = var.stats_port >= 1 && var.stats_port <= 65535
    error_message = "Stats port must be between 1 and 65535."
  }
}

variable "stats_user" {
  description = "Username for HAProxy stats interface"
  type        = string
  default     = "admin"
}

variable "stats_password" {
  description = "Password for HAProxy stats interface"
  type        = string
  sensitive   = true
}

# =============================================================================
# Frontend and Backend Configuration
# =============================================================================

variable "frontends" {
  description = "List of frontend configurations"
  type = list(object({
    name            = string
    bind_address    = optional(string, "*")
    bind_port       = number
    mode            = optional(string, "tcp")
    default_backend = string
    options         = optional(list(string), [])
    # TLS configuration
    ssl             = optional(bool, false)
    ssl_certificate = optional(string, "") # Name of certificate from tls_certificates map
  }))
  default = []

  validation {
    condition = alltrue([
      for f in var.frontends : f.bind_port >= 1 && f.bind_port <= 65535
    ])
    error_message = "All frontend bind_port values must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for f in var.frontends : contains(["tcp", "http"], f.mode)
    ])
    error_message = "Frontend mode must be 'tcp' or 'http'."
  }
}

variable "backends" {
  description = "List of backend configurations"
  type = list(object({
    name    = string
    mode    = optional(string, "tcp")
    balance = optional(string, "roundrobin")
    options = optional(list(string), [])
    servers = list(object({
      name    = string
      address = string
      port    = number
      options = optional(string, "check")
    }))
  }))
  default = []

  validation {
    condition = alltrue([
      for b in var.backends : contains(["tcp", "http"], b.mode)
    ])
    error_message = "Backend mode must be 'tcp' or 'http'."
  }

  validation {
    condition = alltrue([
      for b in var.backends : contains(["roundrobin", "leastconn", "source", "uri", "first"], b.balance)
    ])
    error_message = "Backend balance must be one of: roundrobin, leastconn, source, uri, first."
  }

  validation {
    condition = alltrue(flatten([
      for b in var.backends : [
        for s in b.servers : s.port >= 1 && s.port <= 65535
      ]
    ]))
    error_message = "All backend server port values must be between 1 and 65535."
  }
}

# =============================================================================
# TLS Configuration
# =============================================================================

variable "tls_certificates" {
  description = "Map of TLS certificates for SSL termination. Key is the certificate name, value contains cert and key."
  type = map(object({
    certificate = string
    private_key = string
  }))
  default   = {}
  sensitive = true
}
