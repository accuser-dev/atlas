# =============================================================================
# PostgreSQL Database Module
# =============================================================================
# Deploys PostgreSQL as a system container with optional Prometheus metrics.
# Uses Debian Trixie with cloud-init for configuration.

locals {
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    postgresql_port           = var.postgresql_port
    admin_password            = var.admin_password
    databases                 = var.databases
    users                     = var.users
    allowed_networks          = var.allowed_networks
    postgresql_config         = var.postgresql_config
    enable_metrics            = var.enable_metrics
    metrics_port              = var.metrics_port
    postgres_exporter_version = var.postgres_exporter_version
  })
}

# =============================================================================
# Storage Volume
# =============================================================================

resource "incus_storage_volume" "postgresql_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"
  target  = var.target_node

  config = merge(
    {
      size = var.data_volume_size
      # PostgreSQL runs as postgres user (UID 26 on Debian)
      "initial.uid"  = "26"
      "initial.gid"  = "26"
      "initial.mode" = "0700"
    },
    var.enable_snapshots ? {
      "snapshots.schedule" = var.snapshot_schedule
      "snapshots.expiry"   = var.snapshot_expiry
      "snapshots.pattern"  = var.snapshot_pattern
    } : {}
  )

  content_type = "filesystem"
}

# =============================================================================
# Profile
# =============================================================================

resource "incus_profile" "postgresql" {
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

  # Data volume mount
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "postgresql-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.postgresql_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/postgresql"
      }
    }
  }
}

# =============================================================================
# Container Instance
# =============================================================================

resource "incus_instance" "postgresql" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.postgresql.name])
  target   = var.target_node

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.postgresql,
    incus_storage_volume.postgresql_data
  ]
}
