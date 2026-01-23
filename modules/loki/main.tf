# =============================================================================
# Loki Module
# =============================================================================
# Log aggregation system
# Uses Debian Trixie system container with cloud-init and systemd for configuration

locals {
  # Cloud-init configuration (minimal bootstrap only)
  cloud_init_content = file("${path.module}/templates/cloud-init.yaml.tftpl")

  # Loki configuration for Ansible
  loki_config = templatefile("${path.module}/templates/config.yaml.tftpl", {
    loki_port              = var.loki_port
    retention_period       = var.retention_period
    retention_delete_delay = var.retention_delete_delay
  })
}

resource "incus_storage_volume" "loki_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"

  config = merge(
    {
      size = var.data_volume_size
    },
    var.enable_snapshots ? {
      "snapshots.schedule" = var.snapshot_schedule
      "snapshots.expiry"   = var.snapshot_expiry
      "snapshots.pattern"  = var.snapshot_pattern
    } : {}
  )

  content_type = "filesystem"
}

# Service-specific profile
# Contains resource limits, root disk with size limit, and service-specific devices
# Network is provided by profiles passed via var.profiles
resource "incus_profile" "loki" {
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

  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "loki-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.loki_data[0].name
        pool   = var.storage_pool
        path   = "/loki"
      }
    }
  }

  # Proxy device for external access (bridge networking mode)
  dynamic "device" {
    for_each = var.enable_external_access ? [1] : []
    content {
      name = "loki-proxy"
      type = "proxy"
      properties = {
        listen  = "tcp:0.0.0.0:${var.external_port}"
        connect = "tcp:127.0.0.1:${var.loki_port}"
        bind    = "host"
      }
    }
  }

  depends_on = [
    incus_storage_volume.loki_data
  ]
}

resource "incus_instance" "loki" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.loki.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.loki,
    incus_storage_volume.loki_data
  ]
}
