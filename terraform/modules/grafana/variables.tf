variable "instance_name" {
  description = "Name of the Grafana instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use (system container with cloud-init)"
  type        = string
  default     = "images:alpine/3.21/cloud"
}

variable "grafana_version" {
  description = "Version of Grafana to install"
  type        = string
  default     = "11.4.0"
}

variable "admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
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
  description = "Storage pool for volumes"
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
  description = "Domain name for Grafana (used in server configuration)"
  type        = string
  default     = ""
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

# Dashboard Provisioning
variable "enable_default_dashboards" {
  description = "Enable provisioning of default Atlas dashboards (health monitoring)"
  type        = bool
  default     = true
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
  default     = "@daily"

  validation {
    condition     = can(regex("^(@(hourly|daily|weekly|monthly)|[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+\\s+[0-9*,/-]+)$", var.snapshot_schedule))
    error_message = "Must be a valid cron expression or shorthand (@hourly, @daily, @weekly, @monthly)"
  }
}

variable "snapshot_expiry" {
  description = "How long to keep snapshots (e.g., 7d, 4w, 3m)"
  type        = string
  default     = "7d"

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
