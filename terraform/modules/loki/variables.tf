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
  default     = "docker:ghcr.io/accuser/atlas/loki:latest"
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
  description = "Size of the storage volume (e.g., 50GB)"
  type        = string
  default     = "50GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '50GB' or '100MB'"
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
