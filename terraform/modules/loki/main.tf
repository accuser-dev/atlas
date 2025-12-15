resource "incus_storage_volume" "loki_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = merge(
    {
      size = var.data_volume_size
      # Set initial ownership for Loki user (UID 10001) to allow writes from non-root container
      # Requires Incus 6.8+ (https://linuxcontainers.org/incus/news/2024_12_13_07_12.html)
      "initial.uid"  = "10001"
      "initial.gid"  = "10001"
      "initial.mode" = "0755"
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

  depends_on = [
    incus_storage_volume.loki_data
  ]
}

locals {
  # TLS environment variables (only set when TLS is enabled)
  tls_env_vars = var.enable_tls ? {
    ENABLE_TLS         = "true"
    STEPCA_URL         = var.stepca_url
    STEPCA_FINGERPRINT = var.stepca_fingerprint
    CERT_DURATION      = var.cert_duration
  } : {}

  # Retention environment variables
  retention_env_vars = {
    RETENTION_PERIOD       = var.retention_period
    RETENTION_DELETE_DELAY = var.retention_delete_delay
  }
}

resource "incus_instance" "loki" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.loki.name])

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
    { for k, v in local.tls_env_vars : "environment.${k}" => v },
    { for k, v in local.retention_env_vars : "environment.${k}" => v if v != "" },
  )

  lifecycle {
    precondition {
      condition     = !var.enable_tls || (var.stepca_url != "" && var.stepca_fingerprint != "")
      error_message = "When enable_tls is true, both stepca_url and stepca_fingerprint must be provided."
    }
  }
}
