variable "instance_name" {
  description = "Name of the Prometheus instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "ghcr:accuser-dev/atlas/prometheus:latest"
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

variable "environment_variables" {
  description = "Environment variables for Prometheus container"
  type        = map(string)
  default     = {}
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for Prometheus data"
  type        = bool
  default     = false
}

variable "data_volume_name" {
  description = "Name of the storage volume for Prometheus data"
  type        = string
  default     = "prometheus-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 100GB). Minimum recommended: 10GB"
  type        = string
  default     = "100GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '100GB' or '1TB'"
  }

  validation {
    condition = (
      can(regex("TB$", var.data_volume_size)) ||
      (can(regex("GB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 10)
    )
    error_message = "Prometheus volume size must be at least 10GB for metrics storage"
  }
}

variable "prometheus_port" {
  description = "Port that Prometheus listens on"
  type        = string
  default     = "9090"

  validation {
    condition     = can(regex("^[0-9]+$", var.prometheus_port)) && tonumber(var.prometheus_port) >= 1 && tonumber(var.prometheus_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "prometheus_config" {
  description = "Prometheus configuration file content (prometheus.yml)"
  type        = string
  default     = ""
}

variable "alert_rules" {
  description = "Prometheus alert rules file content (alerts.yml)"
  type        = string
  default     = ""
}

# TLS Configuration
variable "enable_tls" {
  description = "Enable TLS for Prometheus using step-ca"
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
  description = "Duration for TLS certificates (e.g., 24h, 168h). Must be between 1h and 8760h (1 year)."
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+h$", var.cert_duration))
    error_message = "Certificate duration must be in hours format (e.g., '24h', '168h')."
  }

  validation {
    condition     = tonumber(trimsuffix(var.cert_duration, "h")) >= 1 && tonumber(trimsuffix(var.cert_duration, "h")) <= 8760
    error_message = "Certificate duration must be between 1h and 8760h (1 year)."
  }
}

# Retention Configuration
variable "retention_time" {
  description = "How long to retain metrics data (e.g., 15d, 30d, 90d)"
  type        = string
  default     = "30d"

  validation {
    condition     = can(regex("^[0-9]+(d|w|y)$", var.retention_time))
    error_message = "Retention time must be in format like '15d', '4w', or '1y'"
  }
}

variable "retention_size" {
  description = "Maximum size of storage before oldest data is deleted (e.g., 50GB, 90GB). Set to empty string to disable size-based retention."
  type        = string
  default     = ""

  validation {
    condition     = var.retention_size == "" || can(regex("^[0-9]+(MB|GB|TB)$", var.retention_size))
    error_message = "Retention size must be empty or in format like '50GB' or '90GB'"
  }
}

# Incus Metrics Configuration
variable "incus_metrics_certificate" {
  description = "PEM-encoded certificate for scraping Incus metrics (from incus-metrics module)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "incus_metrics_private_key" {
  description = "PEM-encoded private key for scraping Incus metrics (from incus-metrics module)"
  type        = string
  default     = ""
  sensitive   = true
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
