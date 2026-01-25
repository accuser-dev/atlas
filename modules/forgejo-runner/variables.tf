# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the Forgejo runner container instance"
  type        = string
  default     = "forgejo-runner01"
}

variable "profile_name" {
  description = "Name of the Incus profile to create for the runner"
  type        = string
  default     = "forgejo-runner"
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
  description = "Memory limit for the container (e.g., '512MB' or '2GB')"
  type        = string
  default     = "2GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '512MB' or '2GB'."
  }
}

variable "root_disk_size" {
  description = "Size limit for the root disk (e.g., '4GB')"
  type        = string
  default     = "4GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '2GB' or '4GB'."
  }
}

# =============================================================================
# Data Persistence
# =============================================================================

variable "enable_data_persistence" {
  description = "Enable persistent storage volume for runner work directory and cache"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name for the persistent data volume"
  type        = string
  default     = "forgejo-runner-data"
}

variable "data_volume_size" {
  description = "Size of the persistent data volume"
  type        = string
  default     = "20GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '20GB' or '50GB'."
  }
}

# =============================================================================
# Forgejo Configuration (passed to Ansible)
# =============================================================================

variable "forgejo_url" {
  description = "URL of the Forgejo instance (e.g., 'https://git.example.com')"
  type        = string
}

variable "runner_labels" {
  description = "Labels for the runner (e.g., 'debian-trixie:host,linux_amd64:host')"
  type        = string
  default     = "debian-trixie:host,linux_amd64:host"
}

variable "runner_insecure" {
  description = "Skip TLS verification for Forgejo connection (useful for self-signed certs)"
  type        = bool
  default     = false
}
