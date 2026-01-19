# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the Forgejo container instance"
  type        = string
  default     = "forgejo01"
}

variable "profile_name" {
  description = "Name of the Incus profile to create for Forgejo"
  type        = string
  default     = "forgejo"
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

variable "database_network" {
  description = "Secondary network for database connectivity (e.g., OVN management network name). Required when database is on a different network than the primary."
  type        = string
  default     = ""
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
  description = "Enable persistent storage volume for Forgejo data"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name for the persistent data volume"
  type        = string
  default     = "forgejo-data"
}

variable "data_volume_size" {
  description = "Size of the persistent data volume (minimum 10GB recommended)"
  type        = string
  default     = "50GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '50GB' or '100GB'."
  }

  validation {
    condition = (
      can(regex("TB$", var.data_volume_size)) ||
      (can(regex("GB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 10)
    )
    error_message = "Forgejo data volume should be at least 10GB."
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
# Forgejo Configuration
# =============================================================================

variable "forgejo_version" {
  description = "Forgejo version to install"
  type        = string
  default     = "10.0.0"
}

variable "http_port" {
  description = "Port for Forgejo web UI"
  type        = string
  default     = "3000"

  validation {
    condition     = can(regex("^[0-9]+$", var.http_port)) && tonumber(var.http_port) >= 1 && tonumber(var.http_port) <= 65535
    error_message = "HTTP port must be a number between 1 and 65535."
  }
}

variable "ssh_port" {
  description = "Port for Forgejo SSH server (default 2222 since Forgejo runs as non-root)"
  type        = string
  default     = "2222"

  validation {
    condition     = can(regex("^[0-9]+$", var.ssh_port)) && tonumber(var.ssh_port) >= 1 && tonumber(var.ssh_port) <= 65535
    error_message = "SSH port must be a number between 1 and 65535."
  }
}

variable "domain" {
  description = "Domain name for Forgejo (e.g., 'git.example.com')"
  type        = string
  default     = "localhost"
}

variable "root_url" {
  description = "Full root URL for Forgejo (e.g., 'https://git.example.com/'). If empty, constructed from domain."
  type        = string
  default     = ""
}

variable "app_name" {
  description = "Application name displayed in Forgejo"
  type        = string
  default     = "Forgejo"
}

# =============================================================================
# Admin Configuration
# =============================================================================

variable "admin_username" {
  description = "Initial admin username"
  type        = string
  default     = "admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", var.admin_username))
    error_message = "Admin username must start with a letter and contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "admin_password" {
  description = "Initial admin password"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "Admin password must be at least 8 characters."
  }
}

variable "admin_email" {
  description = "Initial admin email address"
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.admin_email))
    error_message = "Admin email must be a valid email address."
  }
}

# =============================================================================
# Database Configuration
# =============================================================================

variable "database_type" {
  description = "Database type (postgres or sqlite3)"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "sqlite3"], var.database_type)
    error_message = "Database type must be 'postgres' or 'sqlite3'."
  }
}

variable "database_host" {
  description = "Database host address (required for postgres)"
  type        = string
  default     = ""
}

variable "database_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

variable "database_name" {
  description = "Database name"
  type        = string
  default     = "forgejo"
}

variable "database_user" {
  description = "Database username"
  type        = string
  default     = "forgejo"
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# SSH Access
# =============================================================================

variable "enable_ssh_access" {
  description = "Enable SSH server for git operations"
  type        = bool
  default     = true
}

variable "enable_external_ssh" {
  description = "Enable external SSH access via proxy device (bridge mode only)"
  type        = bool
  default     = false
}

variable "use_ovn_lb" {
  description = "Use OVN load balancer for external access (disables proxy devices)"
  type        = bool
  default     = false
}

variable "external_ssh_port" {
  description = "External port for SSH access (when enable_external_ssh is true)"
  type        = string
  default     = "2222"

  validation {
    condition     = can(regex("^[0-9]+$", var.external_ssh_port)) && tonumber(var.external_ssh_port) >= 1 && tonumber(var.external_ssh_port) <= 65535
    error_message = "External SSH port must be a number between 1 and 65535."
  }
}

# =============================================================================
# TLS Configuration
# =============================================================================

variable "enable_tls" {
  description = "Enable HTTPS for Forgejo web interface"
  type        = bool
  default     = false
}

variable "tls_certificate" {
  description = "TLS certificate PEM content (required when enable_tls is true)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tls_private_key" {
  description = "TLS private key PEM content (required when enable_tls is true)"
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# Monitoring
# =============================================================================

variable "enable_metrics" {
  description = "Enable Prometheus metrics endpoint"
  type        = bool
  default     = true
}

variable "metrics_token" {
  description = "Bearer token for metrics endpoint (leave empty to disable authentication)"
  type        = string
  default     = ""
  sensitive   = true
}
