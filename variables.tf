variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS management"
  type        = string
  sensitive   = true
}

# Development Network Configuration
variable "development_network_ipv4" {
  description = "IPv4 address for development network"
  type        = string
}

variable "development_network_nat" {
  description = "Enable NAT for development network IPv4"
  type        = string
  default     = "true"
}

variable "development_network_ipv6" {
  description = "IPv6 address for development network"
  type        = string
}

variable "development_network_ipv6_nat" {
  description = "Enable NAT for development network IPv6"
  type        = string
  default     = "true"
}

# Testing Network Configuration
variable "testing_network_ipv4" {
  description = "IPv4 address for testing network"
  type        = string
}

variable "testing_network_nat" {
  description = "Enable NAT for testing network IPv4"
  type        = string
  default     = "true"
}

variable "testing_network_ipv6" {
  description = "IPv6 address for testing network"
  type        = string
}

variable "testing_network_ipv6_nat" {
  description = "Enable NAT for testing network IPv6"
  type        = string
  default     = "true"
}

# Production Network Configuration
variable "production_network_ipv4" {
  description = "IPv4 address for production network"
  type        = string
}

variable "production_network_nat" {
  description = "Enable NAT for production network IPv4"
  type        = string
  default     = "true"
}

variable "production_network_ipv6" {
  description = "IPv6 address for production network"
  type        = string
}

variable "production_network_ipv6_nat" {
  description = "Enable NAT for production network IPv6"
  type        = string
  default     = "true"
}