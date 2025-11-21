# Bootstrap Terraform Version Configuration
# This project uses LOCAL state since it creates the remote state infrastructure

terraform {
  required_version = ">=1.13.5"

  # No backend configuration - uses local state
  # This is intentional as this project creates the remote backend
}
