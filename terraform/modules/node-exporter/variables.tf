variable "instance_name" {
  description = "Name of the Node Exporter instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "docker:prom/node-exporter:latest"
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

variable "network_name" {
  description = "Network name to connect the container to"
  type        = string
  default     = "management"
}

variable "node_exporter_port" {
  description = "Port that Node Exporter listens on"
  type        = string
  default     = "9100"

  validation {
    condition     = can(regex("^[0-9]+$", var.node_exporter_port)) && tonumber(var.node_exporter_port) >= 1 && tonumber(var.node_exporter_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "environment_variables" {
  description = "Environment variables for Node Exporter container"
  type        = map(string)
  default     = {}
}
