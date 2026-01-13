# =============================================================================
# Ceph MON Submodule Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Instance Configuration
# -----------------------------------------------------------------------------

variable "instance_name" {
  description = "Name of the Ceph MON instance"
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
# Data Persistence
# -----------------------------------------------------------------------------

variable "enable_data_persistence" {
  description = "Enable persistent storage for MON data (/var/lib/ceph/mon)"
  type        = bool
  default     = true
}

variable "data_volume_name" {
  description = "Name of the data storage volume"
  type        = string
  default     = ""
}

variable "data_volume_size" {
  description = "Size of the data storage volume"
  type        = string
  default     = "10GB"

  validation {
    condition     = can(regex("^[0-9]+(GB|TB)$", var.data_volume_size))
    error_message = "Data volume size must be in format like '10GB' or '1TB'."
  }
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

variable "mon_id" {
  description = "MON daemon ID (typically matches hostname without domain)"
  type        = string
}

variable "mon_port" {
  description = "Port for MON daemon"
  type        = number
  default     = 6789
}

variable "public_network" {
  description = "Public network CIDR for Ceph"
  type        = string
}

variable "cluster_network" {
  description = "Cluster network CIDR for Ceph (defaults to public_network)"
  type        = string
  default     = ""
}

variable "is_bootstrap" {
  description = "Whether this is the bootstrap MON (first MON in cluster)"
  type        = bool
  default     = false
}

variable "bootstrap_mon_ip" {
  description = "IP address of the bootstrap MON (required for non-bootstrap MONs)"
  type        = string
  default     = ""
}

variable "mon_initial_members" {
  description = "Comma-separated list of initial MON IDs"
  type        = string
  default     = ""
}

variable "mon_host" {
  description = "Comma-separated list of MON addresses"
  type        = string
  default     = ""
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
