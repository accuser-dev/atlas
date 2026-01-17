# =============================================================================
# Ceph Module Variables
# =============================================================================
# This module composes ceph-mon, ceph-mgr, ceph-osd, and ceph-rgw submodules
# to deploy a complete Ceph cluster.

# -----------------------------------------------------------------------------
# Cluster Configuration
# -----------------------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the Ceph cluster"
  type        = string
  default     = "ceph"
}

variable "cluster_fsid" {
  description = "Ceph cluster FSID (UUID). Leave empty to auto-generate."
  type        = string
  default     = ""

  validation {
    condition     = var.cluster_fsid == "" || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.cluster_fsid))
    error_message = "Cluster FSID must be empty or a valid UUID."
  }
}

variable "profiles" {
  description = "List of base Incus profile names to apply to all containers"
  type        = list(string)
  default     = []
}

variable "image" {
  description = "Container image to use for all Ceph containers"
  type        = string
  default     = "images:debian/trixie/cloud"
}

variable "storage_pool" {
  description = "Storage pool for container disks"
  type        = string
  default     = "local"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "storage_network_name" {
  description = "Name of the storage network for Ceph traffic"
  type        = string
}

variable "public_network" {
  description = "Public network CIDR for Ceph client traffic"
  type        = string
}

variable "cluster_network" {
  description = "Cluster network CIDR for OSD replication (defaults to public_network)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# MON Configuration
# -----------------------------------------------------------------------------

variable "mons" {
  description = "Map of MON configurations. Key is the MON ID."
  type = map(object({
    target_node  = string           # Cluster node to pin to
    static_ip    = optional(string) # Static IP on storage network
    is_bootstrap = optional(bool, false)
  }))

  validation {
    condition     = length([for k, v in var.mons : k if v.is_bootstrap]) == 1
    error_message = "Exactly one MON must have is_bootstrap = true."
  }
}

variable "mon_cpu_limit" {
  description = "CPU limit for MON containers"
  type        = string
  default     = "2"
}

variable "mon_memory_limit" {
  description = "Memory limit for MON containers"
  type        = string
  default     = "2GB"
}

variable "mon_data_volume_size" {
  description = "Size of MON data volume"
  type        = string
  default     = "10GB"
}

# -----------------------------------------------------------------------------
# MGR Configuration
# -----------------------------------------------------------------------------

variable "mgrs" {
  description = "Map of MGR configurations. Key is the MGR ID."
  type = map(object({
    target_node = string           # Cluster node to pin to
    static_ip   = optional(string) # Static IP on storage network
  }))
  default = {}
}

variable "mgr_cpu_limit" {
  description = "CPU limit for MGR containers"
  type        = string
  default     = "2"
}

variable "mgr_memory_limit" {
  description = "Memory limit for MGR containers"
  type        = string
  default     = "1GB"
}

variable "enable_mgr_dashboard" {
  description = "Enable Ceph Dashboard on MGR"
  type        = bool
  default     = false
}

variable "enable_mgr_prometheus" {
  description = "Enable Prometheus metrics on MGR"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# OSD Configuration
# -----------------------------------------------------------------------------

variable "osds" {
  description = "Map of OSD configurations. Key is the OSD instance name."
  type = map(object({
    target_node      = string           # Cluster node to pin to (required)
    osd_block_device = string           # Block device path on host
    static_ip        = optional(string) # Static IP on storage network
  }))
}

variable "osd_cpu_limit" {
  description = "CPU limit for OSD containers"
  type        = string
  default     = "4"
}

variable "osd_memory_limit" {
  description = "Memory limit for OSD containers"
  type        = string
  default     = "4GB"
}

# -----------------------------------------------------------------------------
# RGW Configuration
# -----------------------------------------------------------------------------

variable "rgws" {
  description = "Map of RGW configurations. Key is the RGW ID."
  type = map(object({
    target_node = string           # Cluster node to pin to
    static_ip   = optional(string) # Static IP on storage network
  }))
  default = {}
}

variable "rgw_cpu_limit" {
  description = "CPU limit for RGW containers"
  type        = string
  default     = "2"
}

variable "rgw_memory_limit" {
  description = "Memory limit for RGW containers"
  type        = string
  default     = "2GB"
}

variable "rgw_port" {
  description = "Port for RGW S3 API"
  type        = number
  default     = 7480
}
