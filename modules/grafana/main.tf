# =============================================================================
# Grafana Module
# =============================================================================
# Visualization and dashboarding platform
# Uses Alpine Linux system container with cloud-init for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    grafana_version = var.grafana_version
    grafana_port    = var.grafana_port
    domain          = var.domain
    admin_user      = var.admin_user
    admin_password  = var.admin_password
    datasources     = var.datasources
  })
}

resource "incus_storage_volume" "grafana_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

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
resource "incus_profile" "grafana" {
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

  # Data volume for persistent storage
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "grafana-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.grafana_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/grafana"
      }
    }
  }

  depends_on = [
    incus_storage_volume.grafana_data
  ]
}

resource "incus_instance" "grafana" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.grafana.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.grafana,
    incus_storage_volume.grafana_data
  ]
}
