# =============================================================================
# OVN Central Module Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Instance Configuration
# -----------------------------------------------------------------------------

variable "instance_name" {
  description = "Name of the OVN Central container instance"
  type        = string
  default     = "ovn-central01"
}

variable "profile_name" {
  description = "Name of the Incus profile for OVN Central"
  type        = string
  default     = "ovn-central"
}

variable "profiles" {
  description = "List of additional profiles to apply (e.g., base profile for boot.autorestart)"
  type        = list(string)
  default     = []
}

variable "network_name" {
  description = "Network name for OVN Central container (must be non-OVN, typically incusbr0)"
  type        = string
  default     = "incusbr0"
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "images:debian/trixie/cloud"
}

variable "target_node" {
  description = "Target cluster node for container placement (empty for automatic)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Resource Limits
# -----------------------------------------------------------------------------

variable "cpu_limit" {
  description = "CPU limit for the container"
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
  default     = "512MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '512MB' or '1GB'"
  }
}

variable "root_disk_size" {
  description = "Size limit for the root filesystem"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '512MB' or '1GB'"
  }
}

# -----------------------------------------------------------------------------
# Storage Configuration
# -----------------------------------------------------------------------------

variable "storage_pool" {
  description = "Storage pool for volumes"
  type        = string
  default     = "local"
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for OVN databases"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name of the storage volume for OVN data"
  type        = string
  default     = "ovn-central-data"
}

variable "data_volume_size" {
  description = "Size of the OVN data storage volume"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '512MB' or '1GB'"
  }
}

# -----------------------------------------------------------------------------
# OVN Configuration
# -----------------------------------------------------------------------------

variable "northbound_port" {
  description = "Port for OVN northbound database"
  type        = number
  default     = 6641
}

variable "southbound_port" {
  description = "Port for OVN southbound database"
  type        = number
  default     = 6642
}

variable "host_address" {
  description = "Physical network address of the host node (for proxy device connections from other nodes)"
  type        = string
}

# -----------------------------------------------------------------------------
# SSL/TLS Configuration
# -----------------------------------------------------------------------------

variable "enable_ssl" {
  description = "Enable SSL/TLS for OVN database connections"
  type        = bool
  default     = false
}

variable "ssl_ca_cert" {
  description = "CA certificate for SSL connections (PEM format)"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.ssl_ca_cert == "" || can(regex("^-----BEGIN CERTIFICATE-----", var.ssl_ca_cert))
    error_message = "ssl_ca_cert must be a valid PEM-encoded certificate starting with '-----BEGIN CERTIFICATE-----'"
  }
}

variable "ssl_cert" {
  description = "Server certificate for OVN databases (PEM format)"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.ssl_cert == "" || can(regex("^-----BEGIN CERTIFICATE-----", var.ssl_cert))
    error_message = "ssl_cert must be a valid PEM-encoded certificate starting with '-----BEGIN CERTIFICATE-----'"
  }
}

variable "ssl_key" {
  description = "Server private key for OVN databases (PEM format)"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.ssl_key == "" || can(regex("^-----BEGIN .* PRIVATE KEY-----", var.ssl_key))
    error_message = "ssl_key must be a valid PEM-encoded private key"
  }
}
