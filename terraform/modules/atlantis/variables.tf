# Instance Configuration
variable "instance_name" {
  description = "Name of the Atlantis instance"
  type        = string
  default     = "atlantis01"
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
  default     = "atlantis"
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "ghcr:accuser-dev/atlas/atlantis:latest"
}

# Resource Limits
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

# Profile Composition
variable "profiles" {
  description = "List of Incus profile names to apply (should include base profiles for root disk and network)"
  type        = list(string)
  default     = ["default"]
}

variable "storage_pool" {
  description = "Storage pool for the data volume"
  type        = string
  default     = "local"
}

# Storage Configuration
variable "enable_data_persistence" {
  description = "Enable persistent storage for Atlantis data (plans, locks)"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name of the storage volume for Atlantis data"
  type        = string
  default     = "atlantis01-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 10GB). Stores Terraform plans and locks."
  type        = string
  default     = "10GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '10GB' or '100MB'"
  }
}

# GitHub Configuration
variable "github_user" {
  description = "GitHub username or app ID for Atlantis"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token or app private key"
  type        = string
  sensitive   = true
}

variable "github_webhook_secret" {
  description = "Secret for validating GitHub webhooks"
  type        = string
  sensitive   = true
}

variable "repo_allowlist" {
  description = "List of repositories Atlantis is allowed to manage (e.g., ['github.com/org/repo'])"
  type        = list(string)

  validation {
    condition     = length(var.repo_allowlist) > 0
    error_message = "At least one repository must be in the allowlist"
  }
}

# Atlantis Configuration
variable "atlantis_url" {
  description = "External URL of Atlantis for GitHub webhooks (e.g., 'https://atlantis.example.com')"
  type        = string
}

variable "atlantis_port" {
  description = "Port that Atlantis listens on"
  type        = string
  default     = "4141"

  validation {
    condition     = can(regex("^[0-9]+$", var.atlantis_port)) && tonumber(var.atlantis_port) >= 1 && tonumber(var.atlantis_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

# Reverse Proxy Configuration (for Caddy)
variable "domain" {
  description = "Domain name for Atlantis webhook endpoint (for reverse proxy configuration)"
  type        = string
}

variable "allowed_ip_range" {
  description = "IP range allowed to access Atlantis (CIDR notation). For GitHub webhooks, use GitHub's IP ranges."
  type        = string
  default     = "192.30.252.0/22 185.199.108.0/22 140.82.112.0/20 143.55.64.0/20"
}

# Rate Limiting
variable "enable_rate_limiting" {
  description = "Enable rate limiting for webhook endpoint"
  type        = bool
  default     = true
}

variable "rate_limit_requests" {
  description = "Maximum requests allowed per window"
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

# Repo Configuration
variable "enable_repo_config" {
  description = "Enable server-side repo configuration injection"
  type        = bool
  default     = false
}

variable "repo_config" {
  description = "Server-side repos.yaml content (if enable_repo_config is true)"
  type        = string
  default     = ""
}
