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
  default     = "docker:ghcr.io/accuser/atlas/atlas-caddy:latest"
}

variable "cpu_limit" {
  description = "CPU limit for the container"
  type        = string
  default     = "2"
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "1GB"
}

variable "storage_pool" {
  description = "Storage pool for the root disk"
  type        = string
  default     = "local"
}

variable "production_network" {
  description = "Production network name"
  type        = string
  default     = "production"
}

variable "management_network" {
  description = "Management network name"
  type        = string
  default     = "incusbr0"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true
}

variable "service_blocks" {
  description = "List of service configuration blocks for the Caddyfile"
  type        = list(string)
  default     = []
}
