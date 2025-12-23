# =============================================================================
# OpenFGA Authorization Module
# =============================================================================
# Deploys OpenFGA as a fine-grained authorization server.
# Uses Alpine Linux system container with cloud-init for configuration.
#
# OpenFGA implements Google Zanzibar-style authorization, allowing fine-grained
# access control. Incus uses OpenFGA to restrict user access when OIDC
# authentication is enabled.

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    openfga_version = var.openfga_version
    http_port       = var.http_port
    grpc_port       = var.grpc_port
    playground_port = var.playground_port
    metrics_port    = var.metrics_port
    preshared_keys  = var.preshared_keys
  })
}

# Storage volume for OpenFGA data (SQLite database)
resource "incus_storage_volume" "openfga_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = {
    size = var.data_volume_size
  }
}

# Service-specific profile
resource "incus_profile" "openfga" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

  # Root disk with size limit
  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.root_disk_size
    }
  }

  # Persistent data volume
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "openfga-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.openfga_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/openfga"
      }
    }
  }

  depends_on = [
    incus_storage_volume.openfga_data
  ]
}

resource "incus_instance" "openfga" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.openfga.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }
}
