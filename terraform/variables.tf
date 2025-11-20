variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true
}

# Development Network Configuration
variable "development_network_ipv4" {
  description = "IPv4 address for development network"
  type        = string
  default     = "10.10.0.1/24"
}

variable "development_network_nat" {
  description = "Enable NAT for development network IPv4"
  type        = string
  default     = "true"
}


# Testing Network Configuration
variable "testing_network_ipv4" {
  description = "IPv4 address for testing network"
  type        = string
  default     = "10.20.0.1/24"
}

variable "testing_network_nat" {
  description = "Enable NAT for testing network IPv4"
  type        = string
  default     = "true"
}

# Staging Network Configuration
variable "staging_network_ipv4" {
  description = "IPv4 address for staging network"
  type        = string
  default     = "10.30.0.1/24"
}

variable "staging_network_nat" {
  description = "Enable NAT for staging network IPv4"
  type        = string
  default     = "true"
}

# Production Network Configuration
variable "production_network_ipv4" {
  description = "IPv4 address for production network"
  type        = string
  default     = "10.40.0.1/24"
}

variable "production_network_nat" {
  description = "Enable NAT for production network IPv4"
  type        = string
  default     = "true"
}
