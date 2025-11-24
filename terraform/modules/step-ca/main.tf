# step-ca - Internal ACME Certificate Authority
# Provides automated TLS certificate management for internal services

locals {
  # Build DNS names list - always include instance name and localhost
  default_dns_names = "${var.instance_name}.incus,localhost"
  ca_dns_names      = var.ca_dns_names != "" ? "${var.ca_dns_names},${local.default_dns_names}" : local.default_dns_names
}

# Storage volume for CA data (private keys, config, certificate database)
resource "incus_storage_volume" "step_ca_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = {
    size = var.data_volume_size
  }

  content_type = "filesystem"
}

# Profile for step-ca container
resource "incus_profile" "step_ca" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
    "boot.autorestart"      = "true"
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network_name
    }
  }

  # Mount persistent volume for CA data
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "step-ca-data"
      type = "disk"
      properties = {
        source = var.data_volume_name
        pool   = var.storage_pool
        path   = "/home/step"
      }
    }
  }
}

# step-ca container
resource "incus_instance" "step_ca" {
  name  = var.instance_name
  image = var.image
  type  = "container"

  profiles = ["default", incus_profile.step_ca.name]

  config = {
    # Environment variables for CA configuration
    "environment.STEPCA_NAME"          = var.ca_name
    "environment.STEPCA_DNS"           = local.ca_dns_names
    "environment.STEPCA_ADDRESS"       = ":${var.acme_port}"
    "environment.STEPCA_CERT_DURATION" = var.cert_duration
  }

  depends_on = [
    incus_profile.step_ca,
    incus_storage_volume.step_ca_data
  ]
}
