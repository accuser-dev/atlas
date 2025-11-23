resource "incus_storage_volume" "grafana_data" {
  count = var.enable_data_persistence ? 1 : 0

  name = var.data_volume_name
  pool = var.storage_pool

  config = {
    size = var.data_volume_size
  }

  content_type = "filesystem"
}

resource "incus_profile" "grafana" {
  name = var.profile_name

  config = {
    "limits.cpu"    = var.cpu_limit
    "limits.memory" = var.memory_limit
    # OCI containers running as non-root need privileged mode to write to mounted volumes
    # because security.shifted doesn't work for OCI/application containers on ZFS
    "security.privileged" = "true"
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
