# OpenTofu configuration
# Note: The 'terraform' block name is retained for compatibility
# OpenTofu uses the same block syntax as Terraform
terraform {
  required_version = ">=1.6.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">=1.0.0"
    }
  }

  # Remote state backend using Incus S3-compatible storage buckets
  # Configuration is provided via backend-config or environment variables
  # See BACKEND_SETUP.md for detailed setup instructions
  backend "s3" {
    key                         = "atlas/terraform.tfstate"
    region                      = "main"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
    skip_requesting_account_id  = true

    # The following must be provided via:
    # - Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL_S3
    # - Backend config file: tofu init -backend-config=backend.hcl
    #
    # Required values in backend.hcl (OpenTofu 1.6+ syntax):
    #   bucket     = "atlas-terraform-state"
    #   access_key = "<ACCESS_KEY>"
    #   secret_key = "<SECRET_KEY>"
    #   endpoints  = { s3 = "http://localhost:8555" }
  }
}