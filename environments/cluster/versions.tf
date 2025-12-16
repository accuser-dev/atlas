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
  # State is stored separately from iapetus environment
  backend "s3" {
    key                         = "cluster/terraform.tfstate"
    region                      = "main"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
    skip_requesting_account_id  = true

    # The following must be provided via:
    # - Environment variables: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ENDPOINT_URL_S3
    # - Backend config file: terraform init -backend-config=backend.hcl
    #
    # Required values in backend.hcl (Terraform 1.6+ syntax):
    #   bucket     = "atlas-terraform-state"
    #   access_key = "<ACCESS_KEY>"
    #   secret_key = "<SECRET_KEY>"
    #   endpoints  = { s3 = "http://<iapetus-ip>:8555" }
  }
}
