# Node Exporter Module
# Deploys Prometheus Node Exporter for host-level metrics collection

# Incus profile for Node Exporter
resource "incus_profile" "node_exporter" {
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

  # Mount host filesystem read-only for metrics collection
  device {
    name = "host-root"
    type = "disk"
    properties = {
      source   = "/"
      path     = "/host"
      readonly = "true"
    }
  }

  device {
    name = "host-proc"
    type = "disk"
    properties = {
      source   = "/proc"
      path     = "/host/proc"
      readonly = "true"
    }
  }

  device {
    name = "host-sys"
    type = "disk"
    properties = {
      source   = "/sys"
      path     = "/host/sys"
      readonly = "true"
    }
  }
}

# Node Exporter instance
resource "incus_instance" "node_exporter" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default", incus_profile.node_exporter.name]

  config = merge(
    {
      "security.privileged" = "false"
    },
    { for k, v in var.environment_variables : "environment.${k}" => v }
  )
}
