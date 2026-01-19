# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the PostgreSQL container instance"
  type        = string
  default     = "postgresql01"
}

variable "profile_name" {
  description = "Name of the Incus profile to create for PostgreSQL"
  type        = string
  default     = "postgresql"
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
  description = "Enable persistent storage volume for PostgreSQL data"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name for the persistent data volume"
  type        = string
  default     = "postgresql-data"
}

variable "data_volume_size" {
  description = "Size of the persistent data volume (minimum 5GB recommended)"
  type        = string
  default     = "20GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '20GB' or '100GB'."
  }

  validation {
    condition = (
      can(regex("TB$", var.data_volume_size)) ||
      (can(regex("GB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 5)
    )
    error_message = "PostgreSQL data volume should be at least 5GB."
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
# PostgreSQL Configuration
# =============================================================================

variable "postgresql_port" {
  description = "Port for PostgreSQL to listen on"
  type        = string
  default     = "5432"

  validation {
    condition     = can(regex("^[0-9]+$", var.postgresql_port)) && tonumber(var.postgresql_port) >= 1 && tonumber(var.postgresql_port) <= 65535
    error_message = "PostgreSQL port must be a number between 1 and 65535."
  }
}

variable "admin_password" {
  description = "Password for the PostgreSQL admin (postgres) user"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "Admin password must be at least 8 characters."
  }
}

variable "databases" {
  description = "List of databases to create"
  type = list(object({
    name     = string
    owner    = optional(string)
    encoding = optional(string, "UTF8")
  }))
  default = []

  validation {
    condition = alltrue([
      for db in var.databases : can(regex("^[a-z][a-z0-9_]*$", db.name))
    ])
    error_message = "Database names must start with a letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "users" {
  description = "List of database users to create"
  type = list(object({
    name     = string
    password = string
    options  = optional(list(string), [])
  }))
  default   = []
  sensitive = true

  validation {
    condition = alltrue([
      for user in var.users : can(regex("^[a-z][a-z0-9_]*$", user.name))
    ])
    error_message = "Usernames must start with a letter and contain only lowercase letters, numbers, and underscores."
  }
}

variable "allowed_networks" {
  description = "CIDR ranges allowed to connect to PostgreSQL (for pg_hba.conf)"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

  validation {
    condition = alltrue([
      for cidr in var.allowed_networks : can(cidrhost(cidr, 0))
    ])
    error_message = "All entries must be valid CIDR notation."
  }
}

variable "postgresql_config" {
  description = "Additional PostgreSQL configuration to append to postgresql.conf"
  type        = string
  default     = ""
}

# =============================================================================
# Monitoring
# =============================================================================

variable "enable_metrics" {
  description = "Enable Prometheus metrics via postgres_exporter"
  type        = bool
  default     = true
}

variable "metrics_port" {
  description = "Port for postgres_exporter metrics"
  type        = string
  default     = "9187"

  validation {
    condition     = can(regex("^[0-9]+$", var.metrics_port)) && tonumber(var.metrics_port) >= 1 && tonumber(var.metrics_port) <= 65535
    error_message = "Metrics port must be a number between 1 and 65535."
  }
}

variable "postgres_exporter_version" {
  description = "Version of postgres_exporter to install"
  type        = string
  default     = "0.15.0"
}
