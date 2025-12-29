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
}

variable "client_cert" {
  description = "OVN client certificate (PEM format) for SSL connections"
  type        = string
  default     = ""
  sensitive   = true
}

variable "client_key" {
  description = "OVN client private key (PEM format) for SSL connections"
  type        = string
  default     = ""
  sensitive   = true
}

variable "integration_bridge" {
  description = "OVS integration bridge name (default: br-int)"
  type        = string
  default     = ""
}
