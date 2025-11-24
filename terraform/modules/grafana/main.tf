resource "incus_storage_volume" "grafana_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = {
    size = var.data_volume_size
    # Set initial ownership for Grafana user (UID 472) to allow writes from non-root container
    # Requires Incus 6.8+ (https://linuxcontainers.org/incus/news/2024_12_13_07_12.html)
    "initial.uid"  = "472"
    "initial.gid"  = "472"
    "initial.mode" = "0755"
  }

  content_type = "filesystem"
}

resource "incus_profile" "grafana" {
  name = var.profile_name

  config = {
    "limits.cpu"    = var.cpu_limit
    "limits.memory" = var.memory_limit
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
  profiles = ["default", incus_profile.grafana.name]

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
  )
}
