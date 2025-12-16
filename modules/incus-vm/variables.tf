variable "instance_name" {
  description = "Name of the VM instance"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.instance_name)) && length(var.instance_name) >= 2 && length(var.instance_name) <= 63
    error_message = "Instance name must be 2-63 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "profile_name" {
  description = "Name of the Incus profile"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.profile_name)) && length(var.profile_name) >= 2 && length(var.profile_name) <= 63
    error_message = "Profile name must be 2-63 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "image" {
  description = "VM image to use (must be a VM-compatible image from images: remote)"
  type        = string
  default     = "images:ubuntu/24.04"

  validation {
    condition     = can(regex("^images:", var.image))
    error_message = "VM image must be from the 'images:' remote (e.g., 'images:ubuntu/24.04'). Docker/OCI images are not supported for VMs."
  }
}

variable "network_name" {
  description = "Network to attach the VM to"
  type        = string
}

variable "cpu_limit" {
  description = "Number of CPU cores for the VM"
  type        = string
  default     = "2"

  validation {
    condition     = can(regex("^[0-9]+$", var.cpu_limit)) && tonumber(var.cpu_limit) >= 1 && tonumber(var.cpu_limit) <= 64
    error_message = "CPU limit must be a number between 1 and 64."
  }
}

variable "memory_limit" {
  description = "Memory limit for the VM (e.g., 2GB, 4GB)"
  type        = string
  default     = "2GB"

  validation {
    condition     = can(regex("^[0-9]+(MB|GB)$", var.memory_limit))
    error_message = "Memory limit must be in format like '2GB' or '512MB'."
  }
}

variable "root_disk_size" {
  description = "Root disk size for the VM (e.g., 20GB, 50GB)"
  type        = string
  default     = "20GB"

  validation {
    condition     = can(regex("^[0-9]+(GB|TB)$", var.root_disk_size))
    error_message = "Root disk size must be in format like '20GB' or '1TB'."
  }

  validation {
    condition = (
      can(regex("TB$", var.root_disk_size)) ||
      (can(regex("GB$", var.root_disk_size)) && tonumber(regex("^[0-9]+", var.root_disk_size)) >= 10)
    )
    error_message = "Root disk size must be at least 10GB for a VM."
  }
}

variable "storage_pool" {
  description = "Storage pool for the root disk"
  type        = string
  default     = "local"
}

variable "enable_nested_incus" {
  description = "Enable nested Incus (containers/VMs inside this VM). Requires security.nesting=true."
  type        = bool
  default     = true
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for the default user (ubuntu)"
  type        = list(string)
  default     = []
}

variable "packages" {
  description = "Additional packages to install via cloud-init"
  type        = list(string)
  default     = ["git", "curl", "jq"]
}

variable "install_opentofu" {
  description = "Install OpenTofu via cloud-init for infrastructure testing"
  type        = bool
  default     = true
}

variable "install_incus" {
  description = "Install Incus inside the VM for nested container/VM testing"
  type        = bool
  default     = true
}
