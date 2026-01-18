# =============================================================================
# OVN Configuration Module Variables
# =============================================================================

variable "northbound_connection" {
  description = "OVN northbound database connection string (e.g., tcp:192.168.71.5:6641,tcp:192.168.71.2:6641,tcp:192.168.71.8:6641)"
  type        = string

  validation {
    condition     = can(regex("^(tcp|ssl):", var.northbound_connection))
    error_message = "northbound_connection must start with 'tcp:' or 'ssl:' protocol."
  }
}

variable "ca_cert" {
  description = "OVN CA certificate (PEM format) for SSL connections"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.ca_cert == "" || can(regex("^-----BEGIN CERTIFICATE-----", var.ca_cert))
    error_message = "ca_cert must be empty or a valid PEM-formatted certificate starting with '-----BEGIN CERTIFICATE-----'."
  }
}

variable "client_cert" {
  description = "OVN client certificate (PEM format) for SSL connections"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.client_cert == "" || can(regex("^-----BEGIN CERTIFICATE-----", var.client_cert))
    error_message = "client_cert must be empty or a valid PEM-formatted certificate starting with '-----BEGIN CERTIFICATE-----'."
  }
}

variable "client_key" {
  description = "OVN client private key (PEM format) for SSL connections"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.client_key == "" || can(regex("^-----BEGIN (RSA |EC |PRIVATE KEY|ENCRYPTED PRIVATE KEY)", var.client_key))
    error_message = "client_key must be empty or a valid PEM-formatted private key."
  }
}

variable "integration_bridge" {
  description = "OVS integration bridge name (default: br-int)"
  type        = string
  default     = ""

  validation {
    condition     = var.integration_bridge == "" || can(regex("^[a-zA-Z][a-zA-Z0-9_-]*$", var.integration_bridge))
    error_message = "integration_bridge must be empty or a valid bridge name (alphanumeric, hyphens, underscores, starting with a letter)."
  }
}
