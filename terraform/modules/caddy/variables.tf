variable "instance_name" {
  description = "Name of the Caddy instance"
  type        = string
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "ghcr:accuser-dev/atlas/caddy:latest"
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

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profiles for root disk)"
  type        = list(string)
  default     = ["default"]
}

variable "production_network" {
  description = "Production network name (for public-facing applications)"
  type        = string
  default     = "production"
}

variable "management_network" {
  description = "Management network name (for internal services like monitoring)"
  type        = string
  default     = "management"
}

variable "gitops_network" {
  description = "GitOps network name (for Atlantis and CI/CD automation)"
  type        = string
  default     = ""
}

variable "external_network" {
  description = "External network name (for external access, typically incusbr0)"
  type        = string
  default     = "incusbr0"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cloudflare_api_token) >= 40
    error_message = "Cloudflare API token appears invalid (must be at least 40 characters)"
  }
}

variable "service_blocks" {
  description = "List of service configuration blocks for the Caddyfile"
  type        = list(string)
  default     = []
}

# Internal TLS Configuration
variable "internal_ca_certificate" {
  description = "PEM-encoded internal CA certificate for trusting backend TLS connections"
  type        = string
  default     = ""
  sensitive   = true
}
