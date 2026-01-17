terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0.0"
    }
  }
}
