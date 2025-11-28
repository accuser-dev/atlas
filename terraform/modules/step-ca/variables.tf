variable "instance_name" {
  description = "Name of the step-ca instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "ghcr:accuser/atlas/step-ca:latest"
}

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

variable "storage_pool" {
  description = "Storage pool for the data volume"
  type        = string
  default     = "local"
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profiles for root disk and network)"
  type        = list(string)
  default     = ["default"]
}

variable "ca_name" {
  description = "Name of the Certificate Authority"
  type        = string
  default     = "Atlas Internal CA"
}

variable "ca_dns_names" {
  description = "DNS names for the CA certificate (comma-separated)"
  type        = string
  default     = ""
}

variable "ca_password" {
  description = "Password for CA private keys (generated if not provided)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "cert_duration" {
  description = "Default certificate duration (e.g., 24h, 168h)"
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+h$", var.cert_duration))
    error_message = "Certificate duration must be in hours format (e.g., '24h', '168h')"
  }
}

variable "enable_data_persistence" {
  description = "Enable persistent storage for CA data"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name of the storage volume for CA data"
  type        = string
  default     = "step-ca-data"
}

variable "data_volume_size" {
  description = "Size of the storage volume (e.g., 1GB). Minimum recommended: 100MB"
  type        = string
  default     = "1GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '1GB' or '500MB'"
  }

  validation {
    condition = (
      can(regex("GB$", var.data_volume_size)) ||
      (can(regex("MB$", var.data_volume_size)) && tonumber(regex("^[0-9]+", var.data_volume_size)) >= 100)
    )
    error_message = "step-ca volume size must be at least 100MB for CA data and certificates"
  }
}

variable "acme_port" {
  description = "Port for ACME endpoint"
  type        = string
  default     = "9000"

  validation {
    condition     = can(regex("^[0-9]+$", var.acme_port)) && tonumber(var.acme_port) >= 1 && tonumber(var.acme_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}
