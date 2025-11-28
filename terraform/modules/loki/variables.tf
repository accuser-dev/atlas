variable "instance_name" {
  description = "Name of the Loki instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "ghcr:accuser/atlas/loki:latest"
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
  default     = "2GB"

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
  description = "Environment variables for Loki container"
  type        = map(string)
  default     = {}
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for Loki data"
  type        = bool
  default     = false
}

variable "data_volume_name" {
  description = "Name of the storage volume for Loki data"
  type        = string
  default     = "loki-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 50GB). Minimum recommended: 10GB"
  type        = string
  default     = "50GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '50GB' or '100MB'"
  }

  validation {
    condition = (
      can(regex("TB$", var.data_volume_size)) ||
      (can(regex("GB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 10)
    )
    error_message = "Loki volume size must be at least 10GB for log storage"
  }
}

variable "loki_port" {
  description = "Port that Loki listens on"
  type        = string
  default     = "3100"

  validation {
    condition     = can(regex("^[0-9]+$", var.loki_port)) && tonumber(var.loki_port) >= 1 && tonumber(var.loki_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

# TLS Configuration
variable "enable_tls" {
  description = "Enable TLS for Loki using step-ca"
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

# Retention Configuration
variable "retention_period" {
  description = "How long to retain log data (e.g., 168h, 720h, 2160h for 7d, 30d, 90d). Set to empty string to disable retention."
  type        = string
  default     = "720h"

  validation {
    condition     = var.retention_period == "" || can(regex("^[0-9]+h$", var.retention_period))
    error_message = "Retention period must be empty or in hours format (e.g., '720h' for 30 days)"
  }
}

variable "retention_delete_delay" {
  description = "Delay after which chunks will be deleted (e.g., 2h). Must be at least 2h for safety."
  type        = string
  default     = "2h"

  validation {
    condition     = can(regex("^[0-9]+h$", var.retention_delete_delay))
    error_message = "Retention delete delay must be in hours format (e.g., '2h')"
  }
}
