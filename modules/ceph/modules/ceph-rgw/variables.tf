# =============================================================================
# Ceph RGW Submodule Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Instance Configuration
# -----------------------------------------------------------------------------

variable "instance_name" {
  description = "Name of the Ceph RGW instance"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.instance_name)) && length(var.instance_name) >= 2 && length(var.instance_name) <= 63
    error_message = "Instance name must be 2-63 characters, lowercase alphanumeric and hyphens, starting with a letter."
  }
}

variable "profile_name" {
  description = "Name of the Incus profile to create"
  type        = string
}

variable "image" {
  description = "Container image to use"
  type        = string
  default     = "images:debian/trixie/cloud"
}

variable "profiles" {
  description = "List of Incus profile names to apply (base profiles)"
  type        = list(string)
  default     = []
}

variable "target_node" {
  description = "Cluster node to pin this instance to"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Resource Limits
# -----------------------------------------------------------------------------

variable "cpu_limit" {
  description = "CPU limit for the container"
  type        = string
  default     = "2"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be between 1 and 64."
  }
}

variable "memory_limit" {
  description = "Memory limit for the container"
  type        = string
  default     = "2GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '256MB' or '2GB'."
  }
}

variable "root_disk_size" {
  description = "Size of the root disk"
  type        = string
  default     = "5GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '500MB' or '5GB'."
  }
}

variable "storage_pool" {
  description = "Storage pool for disks"
  type        = string
  default     = "local"
}

# -----------------------------------------------------------------------------
# Ceph Configuration
# -----------------------------------------------------------------------------

variable "cluster_fsid" {
  description = "Ceph cluster FSID (UUID)"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.cluster_fsid))
    error_message = "Cluster FSID must be a valid UUID."
  }
}

variable "cluster_name" {
  description = "Ceph cluster name"
  type        = string
  default     = "ceph"
}

variable "rgw_id" {
  description = "RGW daemon ID"
  type        = string
}

variable "mon_initial_members" {
  description = "Comma-separated list of initial MON IDs"
  type        = string
}

variable "mon_host" {
  description = "Comma-separated list of MON addresses"
  type        = string
}

variable "public_network" {
  description = "Public network CIDR for Ceph"
  type        = string
}

variable "rgw_port" {
  description = "Port for RGW S3 API"
  type        = number
  default     = 7480
}

variable "rgw_thread_pool_size" {
  description = "RGW thread pool size"
  type        = number
  default     = 512
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "storage_network_name" {
  description = "Name of the storage network to attach"
  type        = string
}

variable "static_ip" {
  description = "Static IP address on the storage network (optional)"
  type        = string
  default     = ""
}
