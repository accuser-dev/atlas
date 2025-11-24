# Bootstrap Terraform Project
# This project sets up the prerequisites for the main infrastructure:
# - Incus storage buckets configuration
# - Storage pool for Terraform state
# - Storage bucket for Terraform state
# - S3 access credentials
#
# Supports both local and remote Incus instances via the Incus provider

terraform {
  required_version = ">=1.6.0"

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

# Get the current Incus remote URL for S3 endpoint configuration
data "external" "incus_remote" {
  program = ["bash", "-c", <<-EOT
    # Get current remote info from incus remote list
    REMOTE_LINE=$(incus remote list --format csv | grep "(current)")
    if [ -z "$REMOTE_LINE" ]; then
      # Fallback to localhost if no current remote found
      echo '{"url": "https://localhost", "name": "local", "protocol": "https"}'
      exit 0
    fi

    # Parse the CSV: name,url,protocol,auth_type,public,static,global
    NAME=$(echo "$REMOTE_LINE" | cut -d',' -f1 | sed 's/ (current)//')
    URL=$(echo "$REMOTE_LINE" | cut -d',' -f2)

    # Extract protocol and host from URL (e.g., https://192.168.68.76:8443)
    if [[ "$URL" == unix://* ]]; then
      # Local unix socket - use localhost
      PROTOCOL="http"
      HOST="localhost"
    else
      PROTOCOL=$(echo "$URL" | grep -oP '^\w+')
      HOST=$(echo "$URL" | sed -E 's|^\w+://||' | sed -E 's|:[0-9]+$||')
    fi

    # Output as JSON
    echo "{\"url\": \"$URL\", \"name\": \"$NAME\", \"protocol\": \"$PROTOCOL\", \"host\": \"$HOST\"}"
  EOT
  ]
}

locals {
  # Construct the S3 endpoint URL from the current remote
  # Use the provided endpoint if set, otherwise construct from remote
  detected_endpoint = var.storage_buckets_endpoint != "http://localhost:8555" ? var.storage_buckets_endpoint : "${data.external.incus_remote.result.protocol}://${data.external.incus_remote.result.host}:8555"
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
      CREDS_GENERATED=false

      if incus storage bucket key list ${var.storage_pool_name} ${var.bucket_name} --format csv | grep -q "^${var.bucket_key_name},"; then
        # Check if existing key has admin role
        CURRENT_ROLE=$(incus storage bucket key show ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name} | grep "role:" | awk '{print $2}')
        if [ "$CURRENT_ROLE" != "admin" ]; then
          echo "Existing credentials have '$CURRENT_ROLE' role, upgrading to 'admin'..."
          incus storage bucket key delete ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name}
          incus storage bucket key create ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name} --role=admin > ${var.credentials_output_file}
          CREDS_GENERATED=true
          echo ""
          echo "Credentials regenerated with admin role:"
          cat ${var.credentials_output_file}
        else
          echo "Credentials '${var.bucket_key_name}' already exist with admin role"
        fi
      else
        echo "Generating S3 credentials with admin role..."
        incus storage bucket key create ${var.storage_pool_name} ${var.bucket_name} ${var.bucket_key_name} --role=admin > ${var.credentials_output_file}
        CREDS_GENERATED=true
        echo ""
        echo "Credentials saved to: ${var.credentials_output_file}"
        cat ${var.credentials_output_file}
      fi

      # Write backend.hcl directly if new credentials were generated
      if [ "$CREDS_GENERATED" = "true" ]; then
        ACCESS_KEY=$(grep "Access key:" ${var.credentials_output_file} | awk '{print $3}')
        SECRET_KEY=$(grep "Secret key:" ${var.credentials_output_file} | awk '{print $3}')

        cat > ${var.backend_config_output} << BACKEND_EOF
# Terraform S3 Backend Configuration
# Auto-generated by bootstrap process
# DO NOT COMMIT THIS FILE - IT CONTAINS SECRETS

bucket     = "${var.bucket_name}"
access_key = "$ACCESS_KEY"
secret_key = "$SECRET_KEY"

# Terraform 1.6+ requires endpoints block instead of endpoint parameter
endpoints = {
  s3 = "${local.detected_endpoint}"
}
BACKEND_EOF

        chmod 600 ${var.backend_config_output}
        echo ""
        echo "Backend configuration written to: ${var.backend_config_output}"
      fi
    EOT

    environment = var.incus_remote != "" ? {
      INCUS_REMOTE = var.incus_remote
    } : {}
  }

  triggers = {
    bucket_key_name = var.bucket_key_name
    remote          = var.incus_remote
    # Trigger re-run when role requirement changes
    required_role = "admin"
  }
}

# Parse credentials and create backend.hcl
locals {
  # Parse credentials from the .credentials file
  # Format is:
  #   Storage bucket key "terraform-access" added
  #   Access key: XXXXX
  #   Secret key: YYYYY
  credentials_raw   = try(file(var.credentials_output_file), "")
  credentials_lines = split("\n", local.credentials_raw)

  # Find lines containing "Access key:" and "Secret key:" to handle varying formats
  access_key = try(
    trimspace(split(":", [for line in local.credentials_lines : line if can(regex("Access key:", line))][0])[1]),
    ""
  )

  secret_key = try(
    trimspace(split(":", [for line in local.credentials_lines : line if can(regex("Secret key:", line))][0])[1]),
    ""
  )
}

# Note: backend.hcl is now written directly by the generate_credentials provisioner
# This ensures credentials are written immediately after generation, not at a later
# Terraform phase when the locals have already been evaluated with stale values.
