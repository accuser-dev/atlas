terraform {
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = ">= 1.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}
