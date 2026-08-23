# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the Dex container instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile to create"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "images:debian/trixie/cloud"
}

variable "dex_version" {
  description = "Version of Dex to install"
  type        = string
  default     = "2.41.1"
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
  default     = "128MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '128MB' or '1GB'"
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
# Dex Server Configuration
# =============================================================================

variable "issuer_url" {
  description = "The issuer URL for Dex (the public URL clients will use). Must include /dex path."
  type        = string
}

variable "http_port" {
  description = "HTTP port for Dex web interface"
  type        = string
  default     = "5556"

  validation {
    condition     = can(regex("^[0-9]+$", var.http_port)) && tonumber(var.http_port) >= 1 && tonumber(var.http_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "metrics_port" {
  description = "Port for Prometheus metrics endpoint"
  type        = string
  default     = "5558"

  validation {
    condition     = can(regex("^[0-9]+$", var.metrics_port)) && tonumber(var.metrics_port) >= 1 && tonumber(var.metrics_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "grpc_port" {
  description = "gRPC port for Dex API"
  type        = string
  default     = "5557"

  validation {
    condition     = can(regex("^[0-9]+$", var.grpc_port)) && tonumber(var.grpc_port) >= 1 && tonumber(var.grpc_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

# =============================================================================
# GitHub Connector Configuration
# =============================================================================

variable "github_client_id" {
  description = "GitHub OAuth application client ID"
  type        = string
}

variable "github_client_secret" {
  description = "GitHub OAuth application client secret"
  type        = string
  sensitive   = true
}

variable "github_allowed_orgs" {
  description = "List of GitHub organizations allowed to authenticate. Empty means all users."
  type        = list(string)
  default     = []
}

# =============================================================================
# Static Clients Configuration
# =============================================================================

variable "static_clients" {
  description = "List of static OAuth2 clients to register with Dex. Set public=true for CLI clients that don't use a secret."
  type = list(object({
    id            = string
    name          = string
    secret        = optional(string, "")
    public        = optional(bool, false)
    redirect_uris = list(string)
  }))
  default   = []
  sensitive = true
}

# =============================================================================
# Storage Configuration
# =============================================================================

variable "enable_data_persistence" {
  description = "Enable persistent storage for Dex SQLite database"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name of the storage volume for Dex data"
  type        = string
  default     = "dex-data"
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

# TLS Configuration
variable "enable_tls" {
  description = "Enable TLS for Dex using step-ca"
  type        = bool
  default     = false
}

variable "stepca_url" {
  description = "URL of the step-ca ACME endpoint (required if enable_tls is true)"
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

variable "step_version" {
  description = "Version of step-cli to install for TLS certificate management"
  type        = string
  default     = "0.28.2"
}

