# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the OpenFGA container instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile to create"
  type        = string
}

variable "image" {
  description = "Container image to use (system container with cloud-init)"
  type        = string
  default     = "images:alpine/3.21/cloud"
}

variable "cpu_limit" {
  description = "CPU limit for the container (number of cores)"
  type        = string
  default     = "1"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be a number between 1 and 64"
  }
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "256MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '256MB' or '1GB'"
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
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '1GB' or '500MB'"
  }
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profile and network profile)"
  type        = list(string)
  default     = []
}

# =============================================================================
# OpenFGA Server Configuration
# =============================================================================

variable "http_port" {
  description = "HTTP API port"
  type        = string
  default     = "8080"

  validation {
    condition     = can(regex("^[0-9]+$", var.http_port)) && tonumber(var.http_port) >= 1 && tonumber(var.http_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "grpc_port" {
  description = "gRPC API port"
  type        = string
  default     = "8081"

  validation {
    condition     = can(regex("^[0-9]+$", var.grpc_port)) && tonumber(var.grpc_port) >= 1 && tonumber(var.grpc_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "playground_port" {
  description = "Playground web interface port (set to empty to disable)"
  type        = string
  default     = ""

  validation {
    condition     = var.playground_port == "" || (can(regex("^[0-9]+$", var.playground_port)) && can(tonumber(var.playground_port) >= 1) && can(tonumber(var.playground_port) <= 65535))
    error_message = "Port must be empty or a number between 1 and 65535"
  }
}

variable "metrics_port" {
  description = "Port for Prometheus metrics (via profiler endpoint)"
  type        = string
  default     = "3002"

  validation {
    condition     = can(regex("^[0-9]+$", var.metrics_port)) && tonumber(var.metrics_port) >= 1 && tonumber(var.metrics_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

# =============================================================================
# Authentication Configuration
# =============================================================================

variable "preshared_keys" {
  description = "List of preshared keys for API authentication. At least one is required."
  type        = list(string)
  sensitive   = true

  validation {
    condition     = length(var.preshared_keys) > 0
    error_message = "At least one preshared key must be provided for authentication"
  }
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "enable_data_persistence" {
  description = "Enable persistent storage for OpenFGA SQLite database"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name of the storage volume for OpenFGA data"
  type        = string
  default     = "openfga-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.data_volume_size))
    error_message = "Data volume size must be in format like '1GB' or '500MB'"
  }
}

# =============================================================================
# Version Configuration
# =============================================================================

variable "openfga_version" {
  description = "Version of OpenFGA to install"
  type        = string
  default     = "1.8.2"
}
