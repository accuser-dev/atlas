# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the Prefect container instance"
  type        = string
  default     = "prefect01"
}

variable "profile_name" {
  description = "Name of the Incus profile to create for Prefect"
  type        = string
  default     = "prefect"
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

variable "target_node" {
  description = "Target cluster node for the container (for clustered deployments)"
  type        = string
  default     = null
}

# =============================================================================
# Resource Limits
# =============================================================================

variable "cpu_limit" {
  description = "CPU limit for the container (e.g., '1' or '2')"
  type        = string
  default     = "2"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be a number between 1 and 64."
  }
}

variable "memory_limit" {
  description = "Memory limit for the container (e.g., '512MB' or '1GB')"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '512MB' or '1GB'."
  }
}

variable "root_disk_size" {
  description = "Size limit for the root disk (e.g., '2GB')"
  type        = string
  default     = "2GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '1GB' or '2GB'."
  }
}

# =============================================================================
# Data Persistence
# =============================================================================

variable "enable_data_persistence" {
  description = "Enable persistent storage volume for Prefect data"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name for the persistent data volume"
  type        = string
  default     = "prefect-data"
}

variable "data_volume_size" {
  description = "Size of the persistent data volume"
  type        = string
  default     = "5GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '5GB' or '10GB'."
  }
}

variable "enable_snapshots" {
  description = "Enable automatic snapshots for data volume"
  type        = bool
  default     = false
}

variable "snapshot_schedule" {
  description = "Snapshot schedule in cron format or @hourly/@daily/@weekly"
  type        = string
  default     = "@daily"

  validation {
    condition     = can(regex("^(@(hourly|daily|weekly|monthly)|[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+)$", var.snapshot_schedule))
    error_message = "Snapshot schedule must be a valid cron expression or @hourly/@daily/@weekly/@monthly."
  }
}

variable "snapshot_expiry" {
  description = "Snapshot retention period (e.g., '7d', '4w', '3m')"
  type        = string
  default     = "7d"

  validation {
    condition     = can(regex("^[0-9]+[dwm]$", var.snapshot_expiry))
    error_message = "Snapshot expiry must be in format like '7d' (days), '4w' (weeks), or '3m' (months)."
  }
}

variable "snapshot_pattern" {
  description = "Naming pattern for automatic snapshots"
  type        = string
  default     = "auto-{{creation_date}}"
}

# =============================================================================
# Prefect Configuration
# =============================================================================

variable "prefect_port" {
  description = "Port for Prefect server UI and API"
  type        = string
  default     = "4200"

  validation {
    condition     = can(regex("^[0-9]+$", var.prefect_port)) && tonumber(var.prefect_port) >= 1 && tonumber(var.prefect_port) <= 65535
    error_message = "Prefect port must be a number between 1 and 65535."
  }
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "database_host" {
  description = "PostgreSQL host address"
  type        = string
}

variable "database_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

variable "database_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "prefect"
}

variable "database_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "prefect"
}

variable "database_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}
