# Storage Pool Configuration
variable "storage_pool" {
  description = "Name of the storage pool to use for root disks"
  type        = string
  default     = "local"
}

# Development Network Configuration
variable "development_network_ipv4" {
  description = "IPv4 address for development network"
  type        = string
  default     = "10.10.0.1/24"

  validation {
    condition     = can(cidrhost(var.development_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.10.0.1/24)"
  }
}

variable "development_network_nat" {
  description = "Enable NAT for development network IPv4"
  type        = bool
  default     = true
}

variable "development_network_ipv6" {
  description = "IPv6 address for development network (e.g., fd00:10:10::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.development_network_ipv6 == "" || can(cidrhost(var.development_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:10::1/64)"
  }
}

variable "development_network_ipv6_nat" {
  description = "Enable NAT for development network IPv6"
  type        = bool
  default     = true
}

# Testing Network Configuration
variable "testing_network_ipv4" {
  description = "IPv4 address for testing network"
  type        = string
  default     = "10.20.0.1/24"

  validation {
    condition     = can(cidrhost(var.testing_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.20.0.1/24)"
  }
}

variable "testing_network_nat" {
  description = "Enable NAT for testing network IPv4"
  type        = bool
  default     = true
}

variable "testing_network_ipv6" {
  description = "IPv6 address for testing network (e.g., fd00:10:20::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.testing_network_ipv6 == "" || can(cidrhost(var.testing_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:20::1/64)"
  }
}

variable "testing_network_ipv6_nat" {
  description = "Enable NAT for testing network IPv6"
  type        = bool
  default     = true
}

# Staging Network Configuration
variable "staging_network_ipv4" {
  description = "IPv4 address for staging network"
  type        = string
  default     = "10.30.0.1/24"

  validation {
    condition     = can(cidrhost(var.staging_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.30.0.1/24)"
  }
}

variable "staging_network_nat" {
  description = "Enable NAT for staging network IPv4"
  type        = bool
  default     = true
}

variable "staging_network_ipv6" {
  description = "IPv6 address for staging network (e.g., fd00:10:30::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.staging_network_ipv6 == "" || can(cidrhost(var.staging_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:30::1/64)"
  }
}

variable "staging_network_ipv6_nat" {
  description = "Enable NAT for staging network IPv6"
  type        = bool
  default     = true
}

# Production Network Configuration
variable "production_network_ipv4" {
  description = "IPv4 address for production network"
  type        = string
  default     = "10.40.0.1/24"

  validation {
    condition     = can(cidrhost(var.production_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.40.0.1/24)"
  }
}

variable "production_network_nat" {
  description = "Enable NAT for production network IPv4"
  type        = bool
  default     = true
}

variable "production_network_ipv6" {
  description = "IPv6 address for production network (e.g., fd00:10:40::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.production_network_ipv6 == "" || can(cidrhost(var.production_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:40::1/64)"
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
  default     = "10.50.0.1/24"

  validation {
    condition     = can(cidrhost(var.management_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.50.0.1/24)"
  }
}

variable "management_network_nat" {
  description = "Enable NAT for management network IPv4"
  type        = bool
  default     = true
}

variable "management_network_ipv6" {
  description = "IPv6 address for management network (e.g., fd00:10:50::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.management_network_ipv6 == "" || can(cidrhost(var.management_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:50::1/64)"
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
  default     = "10.60.0.1/24"

  validation {
    condition     = can(cidrhost(var.gitops_network_ipv4, 0))
    error_message = "Must be valid CIDR notation (e.g., 10.60.0.1/24)"
  }
}

variable "gitops_network_nat" {
  description = "Enable NAT for GitOps network IPv4"
  type        = bool
  default     = true
}

variable "gitops_network_ipv6" {
  description = "IPv6 address for GitOps network (e.g., fd00:10:60::1/64). Set to empty string to disable IPv6."
  type        = string
  default     = ""

  validation {
    condition     = var.gitops_network_ipv6 == "" || can(cidrhost(var.gitops_network_ipv6, 0))
    error_message = "Must be empty or valid IPv6 CIDR notation (e.g., fd00:10:60::1/64)"
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
