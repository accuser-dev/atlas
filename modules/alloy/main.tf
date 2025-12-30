# =============================================================================
# Alloy Module
# =============================================================================
# Grafana Alloy - OpenTelemetry collector for logs, metrics, and traces
# Replaces Promtail for log shipping to Loki
# Uses Alpine Linux system container with cloud-init for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    alloy_version = var.alloy_version
    http_port     = var.http_port
    loki_push_url = var.loki_push_url
    hostname      = var.instance_name
    extra_labels  = var.extra_labels
  })
}

# Service-specific profile
# Contains resource limits, root disk with size limit, and service-specific devices
# Network is provided by profiles passed via var.profiles
resource "incus_profile" "alloy" {
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

resource "incus_instance" "alloy" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.alloy.name])

  # Pin to specific cluster node if specified
  target = var.target_node != "" ? var.target_node : null

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_profile.alloy
  ]
}
