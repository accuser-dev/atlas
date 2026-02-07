# =============================================================================
# Prefect Server Module
# =============================================================================
# Deploys Prefect server as a system container with PostgreSQL backend.
# Uses Debian Trixie with cloud-init for bootstrap, Ansible for configuration.

locals {
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {})
}

# =============================================================================
# Storage Volume
# =============================================================================

resource "incus_storage_volume" "prefect_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"
  target  = var.target_node

  config = merge(
    {
      size = var.data_volume_size
      # Prefect data owned by root (service runs as root by default)
      "initial.uid"  = "0"
      "initial.gid"  = "0"
      "initial.mode" = "0750"
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

resource "incus_profile" "prefect" {
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
      name = "prefect-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.prefect_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/prefect"
      }
    }
  }
}

# =============================================================================
# Container Instance
# =============================================================================

resource "incus_instance" "prefect" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.prefect.name])
  target   = var.target_node

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  lifecycle {
    precondition {
      condition     = var.database_host != "" && var.database_password != ""
      error_message = "Both database_host and database_password must be provided for Prefect server."
    }
  }

  depends_on = [
    incus_profile.prefect,
    incus_storage_volume.prefect_data
  ]
}
