variable "instance_name" {
  description = "Name of the Promtail instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use (system container with cloud-init)"
  type        = string
  default     = "images:alpine/3.21/cloud"
}

variable "promtail_version" {
  description = "Version of Promtail to install"
  type        = string
  default     = "3.3.2"
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
  default     = "256MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '256MB' or '1GB'"
  }
}

variable "storage_pool" {
  description = "Storage pool for the root disk"
  type        = string
  default     = "local"
}

variable "root_disk_size" {
  description = "Size limit for the root disk (container filesystem)"
  type        = string
  default     = "512MB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '1GB' or '500MB'"
  }
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profile and network profile)"
  type        = list(string)
  default     = ["default"]
}

variable "promtail_port" {
  description = "Port that Promtail listens on for HTTP API"
  type        = string
  default     = "9080"

  validation {
    condition     = can(regex("^[0-9]+$", var.promtail_port)) && tonumber(var.promtail_port) >= 1 && tonumber(var.promtail_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "loki_push_url" {
  description = "URL of the Loki instance to push logs to (e.g., http://loki01.iapetus:3100/loki/api/v1/push)"
  type        = string

  validation {
    condition     = can(regex("^https?://", var.loki_push_url))
    error_message = "Loki push URL must start with http:// or https://"
  }
}

variable "extra_labels" {
  description = "Additional labels to attach to all log entries"
  type        = map(string)
  default     = {}
}

variable "target_node" {
  description = "Target cluster node to pin this instance to (for cluster deployments)"
  type        = string
  default     = ""
}
