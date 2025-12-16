# Bootstrap Terraform Outputs

output "storage_pool_name" {
  description = "Name of the created storage pool"
  value       = var.storage_pool_name
}

output "bucket_name" {
  description = "Name of the created storage bucket"
  value       = var.bucket_name
}

output "storage_buckets_endpoint" {
  description = "S3 endpoint URL for the storage bucket"
  value       = local.detected_endpoint
}

output "backend_config_file" {
  description = "Path to the generated backend configuration file"
  value       = var.backend_config_output
}

output "next_steps" {
  description = "Instructions for next steps"
  value       = <<-EOT
    Bootstrap complete! Next steps:

    1. Return to the project root directory:
       cd ../..

    2. Initialize OpenTofu with remote backend:
       make init

    3. Deploy infrastructure:
       make deploy

    Note: The backend.hcl file contains credentials and is gitignored.
  EOT
}
