resource "incus_storage_volume" "loki_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = {
    size = var.data_volume_size
    # Set initial ownership for Loki user (UID 10001) to allow writes from non-root container
    # Requires Incus 6.8+ (https://linuxcontainers.org/incus/news/2024_12_13_07_12.html)
    "initial.uid"  = "10001"
    "initial.gid"  = "10001"
    "initial.mode" = "0755"
  }

  content_type = "filesystem"
}

resource "incus_profile" "loki" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
    "boot.autorestart"      = "true"
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
    }
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network_name
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
}

resource "incus_instance" "loki" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default", incus_profile.loki.name]

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
    { for k, v in local.tls_env_vars : "environment.${k}" => v },
  )
}
