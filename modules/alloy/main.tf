# =============================================================================
# Alloy Module
# =============================================================================
# Grafana Alloy - OpenTelemetry collector for logs, metrics, and traces
# Replaces Promtail for log shipping to Loki
# Uses Debian Trixie system container with cloud-init and systemd for configuration

locals {
  # Cloud-init configuration (minimal bootstrap only)
  cloud_init_content = file("${path.module}/templates/cloud-init.yaml.tftpl")

  # Alloy River configuration for Ansible
  alloy_config = templatefile("${path.module}/templates/config.alloy.tftpl", {
    loki_push_url          = var.loki_push_url
    hostname               = var.instance_name
    extra_labels           = var.extra_labels
    enable_syslog_receiver = var.enable_syslog_receiver
    syslog_port            = var.syslog_port
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
