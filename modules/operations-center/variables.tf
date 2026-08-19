# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_name" {
  description = "Name of the Operations Center VM instance"
  type        = string
  default     = "operations-center01"
}

variable "profile_name" {
  description = "Name of the Incus profile to create for Operations Center"
  type        = string
  default     = "operations-center"
}

variable "storage_pool" {
  description = "Storage pool to use for the VM"
  type        = string
  default     = "local"
}

variable "profiles" {
  description = "List of Incus profile names to apply (should include base profile and network profile)"
  type        = list(string)
  default     = []
}

variable "target_node" {
  description = "Target cluster node for the VM (for clustered deployments)"
  type        = string
  default     = null
}

# =============================================================================
# Resource Limits
# =============================================================================

variable "cpu_limit" {
  description = "CPU limit for the VM (e.g., '1' or '2')"
  type        = string
  default     = "2"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be a number between 1 and 64."
  }
}

variable "memory_limit" {
  description = "Memory limit for the VM (e.g., '2GB' or '4GB')"
  type        = string
  default     = "4GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '512MB' or '4GB'."
  }
}

variable "root_disk_size" {
  description = "Root disk size for the VM. Use GiB/TiB (binary), not GB/TB (decimal) - IncusOS's installer checks the disk in GiB and refuses to run below its minimum, so a decimal size a few percent short (e.g. '50GB' = 46.57GiB) fails the install's system check."
  type        = string
  default     = "55GiB"

  validation {
    condition     = can(regex("^[0-9]+(GiB|TiB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '55GiB' or '1TiB' (binary units - see description)."
  }

  validation {
    condition = (
      can(regex("TiB$", var.root_disk_size)) ||
      (can(regex("GiB$", var.root_disk_size)) && tonumber(regex("^[0-9]+", var.root_disk_size)) >= 50)
    )
    error_message = "Root disk size must be at least 50GiB - IncusOS's installer refuses to run below that."
  }
}

# =============================================================================
# IncusOS Install Media
# =============================================================================

variable "attach_boot_media" {
  description = "Attach the seeded installer ISO as boot media. Set true to (re)install, then false once IncusOS reports the install complete so the VM boots from its own disk."
  type        = bool
  default     = true
}

variable "boot_media_volume" {
  description = "Name of the pre-imported ISO storage volume (content_type=iso) on storage_pool, built by `make operations-center-iso`. Required when attach_boot_media is true."
  type        = string
  default     = "operations-center01-iso"
}
