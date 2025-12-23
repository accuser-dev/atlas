# =============================================================================
# Dex OIDC Identity Provider Module
# =============================================================================
# Deploys Dex as an OpenID Connect identity provider with GitHub connector.
# Uses Alpine Linux system container with cloud-init for configuration.
#
# Dex acts as a federated OIDC provider, allowing authentication via GitHub
# (or other upstream IdPs) while presenting a unified OIDC interface to clients.

locals {
  # Generate Dex configuration
  dex_config = templatefile("${path.module}/templates/config.yaml.tftpl", {
    issuer_url           = var.issuer_url
    http_port            = var.http_port
    metrics_port         = var.metrics_port
    grpc_port            = var.grpc_port
    github_client_id     = var.github_client_id
    github_client_secret = var.github_client_secret
    github_allowed_orgs  = var.github_allowed_orgs
    static_clients       = var.static_clients
  })

  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    dex_config  = local.dex_config
    dex_version = var.dex_version
    http_port   = var.http_port
  })
}

# Storage volume for Dex data (SQLite database)
resource "incus_storage_volume" "dex_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = {
    size = var.data_volume_size
  }
}

# Service-specific profile
resource "incus_profile" "dex" {
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
      name = "dex-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.dex_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/dex"
      }
    }
  }

  depends_on = [
    incus_storage_volume.dex_data
  ]
}

resource "incus_instance" "dex" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.dex.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }
}
