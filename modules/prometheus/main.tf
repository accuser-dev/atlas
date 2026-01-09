# =============================================================================
# Prometheus Module
# =============================================================================
# Metrics collection and time-series database
# Uses Debian Trixie system container with cloud-init and systemd for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    prometheus_version        = var.prometheus_version
    prometheus_port           = var.prometheus_port
    prometheus_config         = var.prometheus_config
    alert_rules               = var.alert_rules
    retention_time            = var.retention_time
    retention_size            = var.retention_size
    incus_metrics_certificate = var.incus_metrics_certificate
    incus_metrics_private_key = var.incus_metrics_private_key
  })
}

resource "incus_storage_volume" "prometheus_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"
  target  = var.target_node

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
resource "incus_profile" "prometheus" {
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
      name = "prometheus-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.prometheus_data[0].name
        pool   = var.storage_pool
        path   = "/prometheus"
      }
    }
  }

  depends_on = [
    incus_storage_volume.prometheus_data
  ]
}

resource "incus_instance" "prometheus" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.prometheus.name])
  target   = var.target_node

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.prometheus,
    incus_storage_volume.prometheus_data
  ]
}
