variable "instance_name" {
  description = "Name of the cloudflared instance"
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
  description = "List of Incus profile names to apply (should include base profiles for network)"
  type        = list(string)
  default     = ["default"]
}

variable "tunnel_token" {
  description = "Cloudflare Tunnel token from Zero Trust dashboard"
  type        = string
  sensitive   = true
}

variable "metrics_port" {
  description = "Port for the metrics endpoint"
  type        = string
  default     = "2000"

  validation {
    condition     = can(regex("^[0-9]+$", var.metrics_port)) && tonumber(var.metrics_port) >= 1 && tonumber(var.metrics_port) <= 65535
    error_message = "Port must be a number between 1 and 65535"
  }
}

variable "cloudflared_version" {
  description = "Version of cloudflared to install"
  type        = string
  default     = "2025.1.0"
}
