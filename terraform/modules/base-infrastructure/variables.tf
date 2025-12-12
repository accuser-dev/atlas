# Storage Pool Configuration
variable "storage_pool" {
  description = "Name of the storage pool to use for root disks"
  type        = string
  default     = "local"
}

# Production Network Configuration
variable "production_network_ipv4" {
  description = "IPv4 address for production network"
  type        = string
  default     = "10.10.0.1/24"

  validation {
    condition     = can(cidrhost(var.production_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.10.0.1/24)"
  }
}

variable "production_network_nat" {
  description = "Enable NAT for production network IPv4"
  type        = bool
  default     = true
}

variable "production_network_ipv6" {
  description = "IPv6 address for production network (e.g., fd00:10:10::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.production_network_ipv6 == "" || can(cidrhost(var.production_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:10::1/64)"
  }
}

variable "production_network_ipv6_nat" {
  description = "Enable NAT for production network IPv6"
  type        = bool
  default     = true
}

# Management Network Configuration
variable "management_network_ipv4" {
  description = "IPv4 address for management network (monitoring, internal services)"
  type        = string
  default     = "10.20.0.1/24"

  validation {
    condition     = can(cidrhost(var.management_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.20.0.1/24)"
  }
}

variable "management_network_nat" {
  description = "Enable NAT for management network IPv4"
  type        = bool
  default     = true
}

variable "management_network_ipv6" {
  description = "IPv6 address for management network (e.g., fd00:10:20::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.management_network_ipv6 == "" || can(cidrhost(var.management_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:20::1/64)"
  }
}

variable "management_network_ipv6_nat" {
  description = "Enable NAT for management network IPv6"
  type        = bool
  default     = true
}

# GitOps Configuration
variable "enable_gitops" {
  description = "Enable GitOps infrastructure (gitops network and profile)"
  type        = bool
  default     = false
}

variable "gitops_network_ipv4" {
  description = "IPv4 address for GitOps network (Atlantis, CI/CD automation)"
  type        = string
  default     = "10.30.0.1/24"

  validation {
    condition     = can(cidrhost(var.gitops_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.30.0.1/24)"
  }
}

variable "gitops_network_nat" {
  description = "Enable NAT for GitOps network IPv4"
  type        = bool
  default     = true
}

variable "gitops_network_ipv6" {
  description = "IPv6 address for GitOps network (e.g., fd00:10:30::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.gitops_network_ipv6 == "" || can(cidrhost(var.gitops_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:30::1/64)"
  }
}

variable "gitops_network_ipv6_nat" {
  description = "Enable NAT for GitOps network IPv6"
  type        = bool
  default     = true
}

# External Network Configuration
variable "external_network" {
  description = "Name of the external network (typically incusbr0)"
  type        = string
  default     = "incusbr0"
}
