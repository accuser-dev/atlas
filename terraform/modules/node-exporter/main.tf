# =============================================================================
# Node Exporter Module
# =============================================================================
# Deploys Prometheus Node Exporter for host-level metrics collection
# Uses Alpine Linux system container with cloud-init for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    node_exporter_port = var.node_exporter_port
  })
}

# Service-specific profile
# Contains resource limits, root disk, and service-specific devices (host mounts)
# Base network infrastructure is provided by profiles passed via var.profiles
resource "incus_profile" "node_exporter" {
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
  profiles = concat(var.profiles, [incus_profile.node_exporter.name])

  config = {
    "security.privileged"  = "false"
    "cloud-init.user-data" = local.cloud_init_content
  }
}
