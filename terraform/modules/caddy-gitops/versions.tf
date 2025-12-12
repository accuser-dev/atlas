# Terraform and provider version constraints for caddy-gitops module

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 0.1.0"
    }
  }
}
