# =============================================================================
# Promtail Module
# =============================================================================
# Log shipping agent for sending logs to a central Loki instance
# Uses Alpine Linux system container with cloud-init for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    promtail_version = var.promtail_version
    promtail_port    = var.promtail_port
    loki_push_url    = var.loki_push_url
    hostname         = var.instance_name
    extra_labels     = var.extra_labels
  })
}

# Service-specific profile
# Contains resource limits, root disk with size limit, and service-specific devices
# Network is provided by profiles passed via var.profiles
resource "incus_profile" "promtail" {
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
}

resource "incus_instance" "promtail" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.promtail.name])

  # Pin to specific cluster node if specified
  target = var.target_node != "" ? var.target_node : null

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.promtail
  ]
}
