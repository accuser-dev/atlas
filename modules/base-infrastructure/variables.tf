# Storage Pool Configuration
variable "storage_pool" {
  description = "Name of the storage pool to use for root disks"
  type        = string
  default     = "local"
}

# Cluster Configuration
variable "is_cluster" {
  description = "Whether this is a clustered Incus deployment. When true, networks are created with cluster-aware settings."
  type        = bool
  default     = false
}

variable "cluster_target_node" {
  description = "Target cluster node for creating networks (required when is_cluster is true). This is the node where the network will be created first."
  type        = string
  default     = ""
}

# Production Network Configuration
variable "production_network_name" {
  description = "Name of the production network. For IncusOS physical mode, set this to match the physical interface name (e.g., 'eno1') to avoid creating a ghost network."
  type        = string
  default     = "production"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.production_network_name)) && length(var.production_network_name) <= 15
    error_message = "Network name must start with a letter, contain only alphanumeric characters and hyphens, and be at most 15 characters."
  }
}

variable "production_network_type" {
  description = "Network type: 'bridge' (default, NAT) or 'physical' (direct LAN attachment for IncusOS)"
  type        = string
  default     = "bridge"

  validation {
    condition     = contains(["bridge", "physical"], var.production_network_type)
    error_message = "production_network_type must be 'bridge' or 'physical'."
  }
}

variable "production_network_parent" {
  description = "Physical interface name when production_network_type is 'physical' (e.g., 'enp5s0', 'eth1'). Required when type is 'physical'. For IncusOS, ensure the interface has 'role instances' enabled."
  type        = string
  default     = ""
}

variable "production_network_ipv4" {
  description = "IPv4 address for production network (only used when type is 'bridge')"
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
variable "management_network_name" {
  description = "Name of the management network. Set to an existing network name (e.g., 'incusbr0') to use it instead of creating a new one."
  type        = string
  default     = "management"
}

variable "management_network_external" {
  description = "Set to true if the management network already exists and should not be created/managed by Terraform. Useful for clusters where incusbr0 is used."
  type        = bool
  default     = false
}

variable "management_network_ipv4" {
  description = "IPv4 address for management network (monitoring, internal services). Ignored if management_network_external is true."
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

# =============================================================================
# OVN Configuration
# =============================================================================

variable "network_backend" {
  description = "Network backend: 'bridge' (default) or 'ovn' for overlay networking"
  type        = string
  default     = "bridge"

  validation {
    condition     = contains(["bridge", "ovn"], var.network_backend)
    error_message = "network_backend must be 'bridge' or 'ovn'."
  }
}

variable "ovn_uplink_network" {
  description = "Uplink network name for OVN external connectivity (required when network_backend is 'ovn')"
  type        = string
  default     = "ovn-uplink"
}

variable "ovn_integration" {
  description = "Network integration name for cross-server OVN connectivity. Leave empty for local-only OVN."
  type        = string
  default     = ""
}

variable "ovn_production_external" {
  description = "Set to true to use an existing OVN production network instead of creating one. Use this when sharing ovn-production across multiple environments connected to the same OVN Central."
  type        = bool
  default     = false
}

# =============================================================================
# Network ACL Configuration (OVN only)
# =============================================================================

variable "management_network_acls" {
  description = "List of ACL names to apply to the management network (OVN only)"
  type        = list(string)
  default     = []
}

variable "production_network_acls" {
  description = "List of ACL names to apply to the production network (OVN only)"
  type        = list(string)
  default     = []
}

variable "gitops_network_acls" {
  description = "List of ACL names to apply to the gitops network (OVN only)"
  type        = list(string)
  default     = []
}

variable "acl_default_ingress_action" {
  description = "Default action for ingress traffic not matching any ACL rule (allow, drop, reject)"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "drop", "reject"], var.acl_default_ingress_action)
    error_message = "acl_default_ingress_action must be 'allow', 'drop', or 'reject'"
  }
}

variable "acl_default_egress_action" {
  description = "Default action for egress traffic not matching any ACL rule (allow, drop, reject)"
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "drop", "reject"], var.acl_default_egress_action)
    error_message = "acl_default_egress_action must be 'allow', 'drop', or 'reject'"
  }
}

# =============================================================================
# DNS Zone Configuration
# =============================================================================

variable "dns_zone_forward" {
  description = "Name of the Incus network zone for automatic container DNS registration (e.g., 'incus.accuser.dev'). When set, networks will be linked to this zone for automatic A record generation."
  type        = string
  default     = ""
}
