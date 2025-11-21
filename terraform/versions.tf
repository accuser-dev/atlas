terraform {
  required_version = ">=1.13.5"

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
    force_path_style            = true

    # The following must be provided via:
    # - Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
    # - Backend config file: terraform init -backend-config=backend.hcl
    # - CLI flags: terraform init -backend-config="bucket=..." -backend-config="endpoint=..."
    #
    # Required values:
    #   bucket   = "atlas-terraform-state"  # Incus storage bucket name
    #   endpoint = "http://localhost:8555"  # Incus storage buckets endpoint
    #   access_key = "<ACCESS_KEY>"         # Incus bucket access key
    #   secret_key = "<SECRET_KEY>"         # Incus bucket secret key
  }
}