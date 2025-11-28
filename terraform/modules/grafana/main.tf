resource "incus_storage_volume" "grafana_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = merge(
    {
      size = var.data_volume_size
      # Set initial ownership for Grafana user (UID 472) to allow writes from non-root container
      # Requires Incus 6.8+ (https://linuxcontainers.org/incus/news/2024_12_13_07_12.html)
      "initial.uid"  = "472"
      "initial.gid"  = "472"
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
# Contains only resource limits and service-specific devices (data volume)
# Base infrastructure (root disk, network) is provided by profiles passed via var.profiles
resource "incus_profile" "grafana" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

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

locals {
  # TLS environment variables (only set when TLS is enabled)
  tls_env_vars = var.enable_tls ? {
    ENABLE_TLS         = "true"
    STEPCA_URL         = var.stepca_url
    STEPCA_FINGERPRINT = var.stepca_fingerprint
    CERT_DURATION      = var.cert_duration
  } : {}
}

resource "incus_instance" "grafana" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.grafana.name])

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
    { for k, v in local.tls_env_vars : "environment.${k}" => v },
  )

  # Provision datasources if configured
  dynamic "file" {
    for_each = length(var.datasources) > 0 ? [1] : []
    content {
      content = templatefile("${path.module}/templates/datasources.yaml.tftpl", {
        datasources = var.datasources
      })
      target_path = "/etc/grafana/provisioning/datasources/datasources.yaml"
      mode        = "0644"
    }
  }

  # Provision dashboard provider configuration
  dynamic "file" {
    for_each = var.enable_default_dashboards ? [1] : []
    content {
      content     = file("${path.module}/templates/dashboards.yaml.tftpl")
      target_path = "/etc/grafana/provisioning/dashboards/dashboards.yaml"
      mode        = "0644"
    }
  }

  # Provision Atlas Health dashboard
  dynamic "file" {
    for_each = var.enable_default_dashboards ? [1] : []
    content {
      content     = file("${path.module}/dashboards/atlas-health.json")
      target_path = "/etc/grafana/provisioning/dashboards/atlas-health.json"
      mode        = "0644"
    }
  }
}
