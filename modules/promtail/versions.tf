terraform {
  required_version = ">= 1.0"

  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 0.2.0"
    }
  }
}
