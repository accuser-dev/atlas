# =============================================================================
# Alertmanager Module
# =============================================================================
# Deploys Prometheus Alertmanager for alert routing and notification management
# Uses Alpine Linux system container with cloud-init for configuration

locals {
  # Default Alertmanager configuration if none provided
  default_config = <<-EOT
    global:
      resolve_timeout: 5m

    route:
      group_by: ['alertname', 'severity']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'default'

    receivers:
      - name: 'default'
        # No notification channels configured by default
        # Add slack_configs, email_configs, or webhook_configs as needed

    inhibit_rules:
      - source_match:
          severity: 'critical'
        target_match:
          severity: 'warning'
        equal: ['alertname']
  EOT

  alertmanager_config = var.alertmanager_config != "" ? var.alertmanager_config : local.default_config

  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    alertmanager_config = local.alertmanager_config
    alertmanager_port   = var.alertmanager_port
    enable_tls          = var.enable_tls
    stepca_url          = var.stepca_url
    stepca_fingerprint  = var.stepca_fingerprint
    cert_duration       = var.cert_duration
    step_version        = var.step_version
  })
}

resource "incus_storage_volume" "alertmanager_data" {
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
resource "incus_profile" "alertmanager" {
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
      name = "alertmanager-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.alertmanager_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/alertmanager"
      }
    }
  }

  depends_on = [
    incus_storage_volume.alertmanager_data
  ]
}

resource "incus_instance" "alertmanager" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.alertmanager.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  lifecycle {
    precondition {
      condition     = !var.enable_tls || (var.stepca_url != "" && var.stepca_fingerprint != "")
      error_message = "When enable_tls is true, both stepca_url and stepca_fingerprint must be provided."
    }
  }
}
