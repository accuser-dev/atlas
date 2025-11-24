variable "instance_name" {
  description = "Name of the Grafana instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "docker:ghcr.io/accuser/atlas/grafana:latest"
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
  description = "Environment variables for Grafana container"
  type        = map(string)
  default     = {}
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
  description = "Size of the storage volume (e.g., 10GB)"
  type        = string
  default     = "10GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB|TB)$", var.data_volume_size))
    error_message = "Volume size must be in format like '10GB' or '100MB'"
  }
}

variable "domain" {
  description = "Domain name for Grafana (for reverse proxy configuration)"
  type        = string
  default     = ""
}

variable "allowed_ip_range" {
  description = "IP range allowed to access Grafana (CIDR notation)"
  type        = string
  default     = "192.168.68.0/22"

  validation {
    condition     = can(cidrhost(var.allowed_ip_range, 0))
    error_message = "Must be valid CIDR notation (e.g., 192.168.68.0/22)"
  }
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

# TLS Configuration
variable "enable_tls" {
  description = "Enable TLS for Grafana using step-ca"
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
  description = "Duration for TLS certificates (e.g., 24h, 168h)"
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+h$", var.cert_duration))
    error_message = "Certificate duration must be in hours format (e.g., '24h', '168h')"
  }
}
