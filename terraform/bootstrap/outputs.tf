# Bootstrap OpenTofu Outputs

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
  value       = var.storage_buckets_endpoint
}

output "backend_config_file" {
  description = "Path to the generated backend configuration file"
  value       = var.backend_config_output
}

output "next_steps" {
  description = "Instructions for next steps"
  value       = <<-EOT
    Bootstrap complete! Next steps:

    1. Return to main terraform directory:
       cd ..

    2. Initialize OpenTofu with remote backend:
       tofu init -backend-config=backend.hcl

    3. Plan and apply infrastructure:
       tofu plan
       tofu apply

    Note: The backend.hcl file contains credentials and is gitignored.
  EOT
}
