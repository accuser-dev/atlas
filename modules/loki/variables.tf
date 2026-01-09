variable "instance_name" {
  description = "Name of the Loki instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use (system container with cloud-init)"
  type        = string
  default     = "images:debian/trixie/cloud"
}

variable "loki_version" {
  description = "Version of Loki to install"
  type        = string
  default     = "3.3.2"
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
  description = "Storage pool for the data volume"
  type        = string
  default     = "local"
}

variable "root_disk_size" {
  description = "Size limit for the root disk (container filesystem)"
  type        = string
  default     = "2GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '1GB' or '500MB'"
  }
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profile and network profile)"
  type        = list(string)
  default     = ["default"]
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

# Snapshot Scheduling
variable "enable_snapshots" {
  description = "Enable automatic snapshots for the data volume"
  type        = bool
  default     = false
}

variable "snapshot_schedule" {
  description = "Cron expression or shorthand (@hourly, @daily, @weekly) for snapshot schedule"
  type        = string
  default     = "@weekly"

  validation {
    condition     = can(regex("^(@(hourly|daily|weekly|monthly)|[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+)$", var.snapshot_schedule))
    error_message = "Must be a valid cron expression or shorthand (@hourly, @daily, @weekly, @monthly)"
  }
}

variable "snapshot_expiry" {
  description = "How long to keep snapshots (e.g., 7d, 4w, 3m)"
  type        = string
  default     = "2w"

  validation {
    condition     = can(regex("^[0-9]+(d|w|m)$", var.snapshot_expiry))
    error_message = "Must be in format like '7d' (days), '4w' (weeks), or '3m' (months)"
  }
}

variable "snapshot_pattern" {
  description = "Naming pattern for snapshots (supports {{creation_date}})"
  type        = string
  default     = "auto-{{creation_date}}"
}
