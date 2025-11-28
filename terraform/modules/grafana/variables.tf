variable "instance_name" {
  description = "Name of the Grafana instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "ghcr:accuser/atlas/grafana:latest"
}

variable "cpu_limit" {
  description = "CPU limit for the container"
  type        = string
  default     = "2"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be a number between 1 and 64"
  }
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '512MB' or '2GB'"
  }
}

variable "storage_pool" {
  description = "Storage pool for the root disk"
  type        = string
  default     = "local"
}

variable "network_name" {
  description = "Network name to connect the container to"
  type        = string
  default     = "management"
}

variable "environment_variables" {
  description = "Environment variables for Grafana container"
  type        = map(string)
  default     = {}
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for Grafana data"
  type        = bool
  default     = false
}

variable "data_volume_name" {
  description = "Name of the storage volume for Grafana data"
  type        = string
  default     = "grafana-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 10GB). Minimum recommended: 1GB"
  type        = string
  default     = "10GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '10GB' or '100MB'"
  }

  validation {
    condition = (
      can(regex("TB$", var.data_volume_size)) ||
      (can(regex("GB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 1) ||
      (can(regex("MB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 1024)
    )
    error_message = "Grafana volume size must be at least 1GB (or 1024MB) for reliable operation"
  }
}

variable "domain" {
  description = "Domain name for Grafana (for reverse proxy configuration)"
  type        = string
  default     = ""
}

variable "allowed_ip_range" {
  description = "IP range allowed to access Grafana (CIDR notation)"
  type        = string
  default     = "192.168.68.0/22"

  validation {
    condition     = can(cidrhost(var.allowed_ip_range, 0))
    error_message = "Must be valid CIDR notation (e.g., 192.168.68.0/22)"
  }
}

variable "grafana_port" {
  description = "Port that Grafana listens on"
  type        = string
  default     = "3000"

  validation {
    condition     = can(regex("^[0-9]+$", var.grafana_port)) && tonumber(var.grafana_port) >= 1 && tonumber(var.grafana_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

# TLS Configuration
variable "enable_tls" {
  description = "Enable TLS for Grafana using step-ca"
  type        = bool
  default     = false
}

variable "stepca_url" {
  description = "URL of the step-ca server (required if enable_tls is true)"
  type        = string
  default     = ""
}

variable "stepca_fingerprint" {
  description = "Fingerprint of the step-ca root certificate (required if enable_tls is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cert_duration" {
  description = "Duration for TLS certificates (e.g., 24h, 168h)"
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+h$", var.cert_duration))
    error_message = "Certificate duration must be in hours format (e.g., '24h', '168h')"
  }
}

# Datasource Provisioning
variable "datasources" {
  description = "List of datasources to provision in Grafana"
  type = list(object({
    name            = string
    type            = string
    url             = string
    is_default      = optional(bool, false)
    tls_skip_verify = optional(bool, false)
  }))
  default = []
}

# Rate Limiting
variable "enable_rate_limiting" {
  description = "Enable rate limiting for this service"
  type        = bool
  default     = true
}

variable "rate_limit_requests" {
  description = "Maximum requests allowed per window for normal endpoints"
  type        = number
  default     = 100

  validation {
    condition     = var.rate_limit_requests >= 1 && var.rate_limit_requests <= 10000
    error_message = "Rate limit must be between 1 and 10000 requests"
  }
}

variable "rate_limit_window" {
  description = "Time window for rate limiting (e.g., 1m, 5m, 1h)"
  type        = string
  default     = "1m"

  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.rate_limit_window))
    error_message = "Rate limit window must be in format like '1m', '30s', or '1h'"
  }
}

variable "login_rate_limit_requests" {
  description = "Maximum requests allowed per window for login endpoints (stricter)"
  type        = number
  default     = 10

  validation {
    condition     = var.login_rate_limit_requests >= 1 && var.login_rate_limit_requests <= 1000
    error_message = "Login rate limit must be between 1 and 1000 requests"
  }
}

variable "login_rate_limit_window" {
  description = "Time window for login endpoint rate limiting"
  type        = string
  default     = "1m"

  validation {
    condition     = can(regex("^[0-9]+(s|m|h)$", var.login_rate_limit_window))
    error_message = "Login rate limit window must be in format like '1m', '30s', or '1h'"
  }
}

# Dashboard Provisioning
variable "enable_default_dashboards" {
  description = "Enable provisioning of default Atlas dashboards (health monitoring)"
  type        = bool
  default     = true
}
