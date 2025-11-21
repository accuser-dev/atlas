# Bootstrap Terraform Variables

# Incus connection settings
# The Incus provider and CLI use the INCUS_REMOTE environment variable
# or the default remote configured in ~/.config/incus/config.yml

variable "incus_remote" {
  description = "Incus remote to use (set via INCUS_REMOTE env var or leave empty for default). Example: 'production' or 'staging'"
  type        = string
  default     = ""
}

variable "accept_remote_certificate" {
  description = "Automatically accept remote server certificate (use with caution in production)"
  type        = bool
  default     = false
}

# Storage configuration
variable "storage_buckets_address" {
  description = "Address for Incus storage buckets S3 API (e.g., ':8555' or '0.0.0.0:8555')"
  type        = string
  default     = ":8555"
}

variable "storage_pool_name" {
  description = "Name of the Incus storage pool for Terraform state"
  type        = string
  default     = "terraform-state"
}

variable "storage_pool_driver" {
  description = "Storage driver to use (dir, zfs, btrfs, lvm)"
  type        = string
  default     = "dir"
}

variable "bucket_name" {
  description = "Name of the storage bucket for Terraform state"
  type        = string
  default     = "atlas-terraform-state"
}

variable "bucket_key_name" {
  description = "Name for the S3 access key"
  type        = string
  default     = "terraform-access"
}

# Output configuration
variable "credentials_output_file" {
  description = "Path to save the generated credentials"
  type        = string
  default     = ".credentials"
}

variable "backend_config_output" {
  description = "Path to save the backend configuration for main Terraform project"
  type        = string
  default     = "../backend.hcl"
}

variable "storage_buckets_endpoint" {
  description = "S3 endpoint URL for Incus storage buckets (use remote server IP for remote Incus)"
  type        = string
  default     = "http://localhost:8555"
}
