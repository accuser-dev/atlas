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
}

# Storage volume for Dex data (SQLite database)
resource "incus_storage_volume" "dex_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = {
    size               = var.data_volume_size
    "security.shifted" = "true"
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
        path   = "/var/dex"
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
    # Override OCI UID/GID to run as root to allow writing to /var/dex
    "oci.uid"        = "0"
    "oci.gid"        = "0"
    "oci.entrypoint" = "dex serve /etc/dex/config.yaml"
  }

  # Inject Dex configuration file
  # Mode 0644 allows the dex user (uid 1001) to read the config
  file {
    content     = local.dex_config
    target_path = "/etc/dex/config.yaml"
    mode        = "0644"
    uid         = 1001
    gid         = 1001
  }

  # Workaround for Incus provider issue with OCI containers
  # The provider sometimes fails to read PID after creation but the container works
  lifecycle {
    ignore_changes = [image]
  }
}
