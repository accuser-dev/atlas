terraform {
  required_version = ">= 1.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 0.1.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
  }
}
