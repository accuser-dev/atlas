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
# The provider uses the Incus client configuration automatically
# Configure remote via:
#   1. Environment variable: export INCUS_REMOTE=myremote
#   2. Incus client default: incus remote switch myremote
#   3. Incus client config: ~/.config/incus/config.yml
provider "incus" {
  generate_client_certificates = true
  accept_remote_certificate    = var.accept_remote_certificate
}

# Configure Incus storage buckets address via local-exec
# Note: The Incus provider doesn't yet support server config resources
# The incus command will use INCUS_REMOTE env var or default remote
resource "null_resource" "configure_storage_buckets" {
  provisioner "local-exec" {
    command = <<-EOT
      incus config get core.storage_buckets_address || \
      incus config set core.storage_buckets_address ${var.storage_buckets_address}
      echo "Storage buckets address configured: ${var.storage_buckets_address}"
    EOT

    environment = var.incus_remote != "" ? {
      INCUS_REMOTE = var.incus_remote
    } : {}
  }

  triggers = {
    address = var.storage_buckets_address
    remote  = var.incus_remote
  }
}

# Create storage pool via local-exec
# Note: The Incus provider doesn't yet support storage pool creation for buckets
resource "null_resource" "create_storage_pool" {
  depends_on = [null_resource.configure_storage_buckets]

  provisioner "local-exec" {
    command = <<-EOT
      if incus storage list --format csv | grep -q "^${var.storage_pool_name},"; then
        echo "Storage pool '${var.storage_pool_name}' already exists"
      else
        echo "Creating storage pool '${var.storage_pool_name}'..."
        incus storage create ${var.storage_pool_name} ${var.storage_pool_driver}
        echo "Storage pool created"
      fi
    EOT

    environment = var.incus_remote != "" ? {
      INCUS_REMOTE = var.incus_remote
    } : {}
  }

  triggers = {
    pool_name = var.storage_pool_name
    driver    = var.storage_pool_driver
    remote    = var.incus_remote
  }
}

# Create storage bucket via local-exec
# Note: The Incus provider doesn't yet support storage bucket resources
resource "null_resource" "create_storage_bucket" {
  depends_on = [null_resource.create_storage_pool]

  provisioner "local-exec" {
    command = <<-EOT
      if incus storage bucket list ${var.storage_pool_name} --format csv | grep -q "^${var.bucket_name},"; then
        echo "Storage bucket '${var.bucket_name}' already exists"
      else
        echo "Creating storage bucket '${var.bucket_name}'..."
        incus storage bucket create ${var.storage_pool_name} ${var.bucket_name}
        echo "Storage bucket created"
      fi
    EOT

    environment = var.incus_remote != "" ? {
      INCUS_REMOTE = var.incus_remote
    } : {}
  }

  triggers = {
    pool_name   = var.storage_pool_name
    bucket_name = var.bucket_name
    remote      = var.incus_remote
  }
}

# Generate S3 credentials via local-exec
# Note: The Incus provider doesn't yet support storage bucket key resources
resource "null_resource" "generate_credentials" {
  depends_on = [null_resource.create_storage_bucket]

  provisioner "local-exec" {
    command = <<-EOT
      if incus storage bucket key list ${var.storage_pool_name} ${var.bucket_name} --format csv | grep -q "^${var.bucket_key_name},"; then
        echo "Credentials '${var.bucket_key_name}' already exist"
        echo ""
        echo "To regenerate credentials:"
        echo "  incus storage bucket key delete ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name}"
        echo "  terraform taint null_resource.generate_credentials"
        echo "  terraform apply"
      else
        echo "Generating S3 credentials..."
        incus storage bucket key create ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name} > ${var.credentials_output_file}
        echo ""
        echo "Credentials saved to: ${var.credentials_output_file}"
        cat ${var.credentials_output_file}
      fi
    EOT

    environment = var.incus_remote != "" ? {
      INCUS_REMOTE = var.incus_remote
    } : {}
  }

  triggers = {
    bucket_key_name = var.bucket_key_name
    remote          = var.incus_remote
  }
}

# Parse credentials and create backend.hcl
locals {
  # Parse credentials from the .credentials file
  # Format from incus storage bucket key create:
  #   Storage bucket key "name" added
  #   Access key: XXXXX
  #   Secret key: YYYYY
  credentials_raw   = try(file(var.credentials_output_file), "")
  credentials_lines = split("\n", local.credentials_raw)

  # Find lines containing "Access key:" and "Secret key:"
  access_key = try(
    trimspace(split(":", [for line in local.credentials_lines : line if can(regex("Access key:", line))][0])[1]),
    ""
  )

  secret_key = try(
    trimspace(split(":", [for line in local.credentials_lines : line if can(regex("Secret key:", line))][0])[1]),
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
