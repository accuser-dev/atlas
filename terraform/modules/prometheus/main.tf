resource "incus_storage_volume" "prometheus_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = merge(
    {
      size = var.data_volume_size
      # Set initial ownership for Prometheus user (UID 65534/nobody) to allow writes from non-root container
      # Requires Incus 6.8+ (https://linuxcontainers.org/incus/news/2024_12_13_07_12.html)
      "initial.uid"  = "65534"
      "initial.gid"  = "65534"
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
    RETENTION_TIME = var.retention_time
    RETENTION_SIZE = var.retention_size
  }
}

resource "incus_instance" "prometheus" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.prometheus.name])

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
    { for k, v in local.tls_env_vars : "environment.${k}" => v },
    { for k, v in local.retention_env_vars : "environment.${k}" => v if v != "" },
  )

  dynamic "file" {
    for_each = var.prometheus_config != "" ? [1] : []
    content {
      content     = var.prometheus_config
      target_path = "/etc/prometheus/prometheus.yml"
      mode        = "0644"
    }
  }

  dynamic "file" {
    for_each = var.alert_rules != "" ? [1] : []
    content {
      content     = var.alert_rules
      target_path = "/etc/prometheus/alerts/alerts.yml"
      mode        = "0644"
    }
  }

  # Incus metrics certificate (for mTLS authentication to Incus API)
  dynamic "file" {
    for_each = var.incus_metrics_certificate != "" ? [1] : []
    content {
      content     = var.incus_metrics_certificate
      target_path = "/etc/prometheus/tls/metrics.crt"
      mode        = "0644"
    }
  }

  # Incus metrics private key
  # Note: mode 0644 is required because Prometheus runs as nobody (UID 65534)
  # and Incus file injection creates files as root. The key is only accessible
  # within the container and the mTLS connection to the local Incus API.
  dynamic "file" {
    for_each = var.incus_metrics_private_key != "" ? [1] : []
    content {
      content     = var.incus_metrics_private_key
      target_path = "/etc/prometheus/tls/metrics.key"
      mode        = "0644"
    }
  }

  lifecycle {
    precondition {
      condition     = !var.enable_tls || (var.stepca_url != "" && var.stepca_fingerprint != "")
      error_message = "When enable_tls is true, both stepca_url and stepca_fingerprint must be provided."
    }
  }
}
