# Bootstrap Terraform Project
# This project sets up the prerequisites for the main infrastructure:
# - Incus storage buckets configuration
# - Storage pool for Terraform state
# - Storage bucket for Terraform state
# - S3 access credentials
#
# Supports both local and remote Incus instances via the Incus provider

terraform {
  required_version = ">=1.13.5"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">=1.0.0"
    }
  }
}

# Incus provider configuration
# Configure via environment variables or terraform.tfvars:
#   INCUS_REMOTE="myremote"
#   INCUS_CONFIG_DIR="~/.config/incus"
# Or for remote with TLS:
#   incus_remote_address = "https://192.168.1.100:8443"
#   incus_remote_password = "password"  # For first-time auth
provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate     = var.accept_remote_certificate

  # Optional: specify remote address directly
  # remote {
  #   name     = var.incus_remote_name
  #   address  = var.incus_remote_address
  #   password = var.incus_remote_password  # Only needed for initial auth
  # }
}

# Configure Incus storage buckets address via local-exec
# Note: The Incus provider doesn't yet support server config resources
resource "null_resource" "configure_storage_buckets" {
  provisioner "local-exec" {
    command = <<-EOT
      ${var.incus_command} config get core.storage_buckets_address || \
      ${var.incus_command} config set core.storage_buckets_address ${var.storage_buckets_address}
      echo "Storage buckets address configured: ${var.storage_buckets_address}"
    EOT
  }

  triggers = {
    address = var.storage_buckets_address
  }
}

# Create storage pool via local-exec
# Note: The Incus provider doesn't yet support storage pool creation for buckets
resource "null_resource" "create_storage_pool" {
  depends_on = [null_resource.configure_storage_buckets]

  provisioner "local-exec" {
    command = <<-EOT
      if ${var.incus_command} storage list --format csv | grep -q "^${var.storage_pool_name},"; then
        echo "Storage pool '${var.storage_pool_name}' already exists"
      else
        echo "Creating storage pool '${var.storage_pool_name}'..."
        ${var.incus_command} storage create ${var.storage_pool_name} ${var.storage_pool_driver}
        echo "Storage pool created"
      fi
    EOT
  }

  triggers = {
    pool_name = var.storage_pool_name
    driver    = var.storage_pool_driver
  }
}

# Create storage bucket via local-exec
# Note: The Incus provider doesn't yet support storage bucket resources
resource "null_resource" "create_storage_bucket" {
  depends_on = [null_resource.create_storage_pool]

  provisioner "local-exec" {
    command = <<-EOT
      if ${var.incus_command} storage bucket list ${var.storage_pool_name} --format csv | grep -q "^${var.bucket_name},"; then
        echo "Storage bucket '${var.bucket_name}' already exists"
      else
        echo "Creating storage bucket '${var.bucket_name}'..."
        ${var.incus_command} storage bucket create ${var.storage_pool_name} ${var.bucket_name}
        echo "Storage bucket created"
      fi
    EOT
  }

  triggers = {
    pool_name  = var.storage_pool_name
    bucket_name = var.bucket_name
  }
}

# Generate S3 credentials via local-exec
# Note: The Incus provider doesn't yet support storage bucket key resources
resource "null_resource" "generate_credentials" {
  depends_on = [null_resource.create_storage_bucket]

  provisioner "local-exec" {
    command = <<-EOT
      if ${var.incus_command} storage bucket key list ${var.storage_pool_name} ${var.bucket_name} --format csv | grep -q "^${var.bucket_key_name},"; then
        echo "Credentials '${var.bucket_key_name}' already exist"
        echo ""
        echo "To regenerate credentials:"
        echo "  ${var.incus_command} storage bucket key delete ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name}"
        echo "  terraform taint null_resource.generate_credentials"
        echo "  terraform apply"
      else
        echo "Generating S3 credentials..."
        ${var.incus_command} storage bucket key create ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name} > ${var.credentials_output_file}
        echo ""
        echo "Credentials saved to: ${var.credentials_output_file}"
        cat ${var.credentials_output_file}
      fi
    EOT
  }

  triggers = {
    bucket_key_name = var.bucket_key_name
  }
}

# Parse credentials and create backend.hcl
locals {
  # Parse credentials from the .credentials file
  # Format is:
  #   Access key: XXXXX
  #   Secret key: YYYYY
  credentials_raw = try(file(var.credentials_output_file), "")
  credentials_lines = split("\n", local.credentials_raw)

  access_key = try(
    trimspace(split(":", local.credentials_lines[0])[1]),
    ""
  )

  secret_key = try(
    trimspace(split(":", local.credentials_lines[1])[1]),
    ""
  )
}

# Create backend.hcl file for main Terraform project
resource "local_file" "backend_config" {
  depends_on = [null_resource.generate_credentials]

  filename = var.backend_config_output

  content = templatefile("${path.module}/templates/backend.hcl.tftpl", {
    bucket     = var.bucket_name
    endpoint   = var.storage_buckets_endpoint
    access_key = local.access_key
    secret_key = local.secret_key
  })

  file_permission = "0600"

  lifecycle {
    precondition {
      condition     = fileexists(var.credentials_output_file) || !fileexists(var.backend_config_output)
      error_message = "Credentials file not found. Ensure terraform apply completes successfully to generate credentials."
    }
  }
}
