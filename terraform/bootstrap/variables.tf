# Bootstrap Terraform Variables

variable "storage_buckets_address" {
  description = "Address for Incus storage buckets S3 API (e.g., ':8555' or '127.0.0.1:8555')"
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
  description = "S3 endpoint URL for Incus storage buckets"
  type        = string
  default     = "http://localhost:8555"
}
