variable "logging_name" {
  description = "Unique name for the logging target configuration (e.g., 'loki01')"
  type        = string
  default     = "loki01"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.logging_name))
    error_message = "Logging name must start with a letter and contain only lowercase letters, numbers, and hyphens"
  }
}

variable "loki_address" {
  description = "Address of the Loki server including protocol and port (e.g., 'http://loki01.incus:3100')"
  type        = string

  validation {
    condition     = can(regex("^https?://", var.loki_address))
    error_message = "Loki address must start with http:// or https://"
  }
}

variable "log_types" {
  description = "Comma-separated list of event types to send to Loki (lifecycle, logging, network-acl)"
  type        = string
  default     = "lifecycle,logging"

  validation {
    condition     = alltrue([for t in split(",", var.log_types) : contains(["lifecycle", "logging", "network-acl"], trimspace(t))])
    error_message = "Log types must be comma-separated list of: lifecycle, logging, network-acl"
  }
}

variable "labels" {
  description = "Comma-separated list of labels to include in Loki log entries"
  type        = string
  default     = ""
}

variable "instance_name" {
  description = "Name to use as the instance field in Loki events (defaults to server hostname)"
  type        = string
  default     = ""
}

variable "retry_count" {
  description = "Number of delivery retry attempts"
  type        = number
  default     = 3

  validation {
    condition     = var.retry_count >= 1 && var.retry_count <= 10
    error_message = "Retry count must be between 1 and 10"
  }
}

variable "username" {
  description = "Username for Loki authentication (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "password" {
  description = "Password for Loki authentication (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ca_cert" {
  description = "CA certificate for TLS verification (optional, for HTTPS connections)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "lifecycle_types" {
  description = "Comma-separated list of instance types for lifecycle events (empty for all)"
  type        = string
  default     = ""
}

variable "lifecycle_projects" {
  description = "Comma-separated list of projects for lifecycle events (empty for all)"
  type        = string
  default     = ""
}
