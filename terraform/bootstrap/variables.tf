# Bootstrap Terraform Variables

# Incus connection settings
variable "incus_command" {
  description = "Incus command to use (e.g., 'incus' for local or 'incus --remote myremote' for remote)"
  type        = string
  default     = "incus"
}

variable "accept_remote_certificate" {
  description = "Automatically accept remote server certificate (use with caution)"
  type        = bool
  default     = false
}

variable "incus_remote_name" {
  description = "Name of the Incus remote to use"
  type        = string
  default     = ""
}

variable "incus_remote_address" {
  description = "Address of remote Incus server (e.g., 'https://192.168.1.100:8443')"
  type        = string
  default     = ""
}

variable "incus_remote_password" {
  description = "Password for initial authentication with remote Incus server"
  type        = string
  default     = ""
  sensitive   = true
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
