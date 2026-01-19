# =============================================================================
# HAProxy Module
# =============================================================================
# Deploys HAProxy load balancer for distributing traffic to backend servers
# Uses Debian Trixie system container with cloud-init and systemd for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    haproxy_config   = local.haproxy_config
    tls_certificates = var.tls_certificates
  })

  # Generate HAProxy configuration
  haproxy_config = templatefile("${path.module}/templates/haproxy.cfg.tftpl", {
    stats_port     = var.stats_port
    stats_user     = var.stats_user
    stats_password = var.stats_password
    frontends      = var.frontends
    backends       = var.backends
  })
}

# Service-specific profile
# Contains resource limits and root disk with size limit
# Base infrastructure (network) is provided by profiles passed via var.profiles
resource "incus_profile" "haproxy" {
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

resource "incus_instance" "haproxy" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.haproxy.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  # Static IP configuration - overrides the network device from profile
  dynamic "device" {
    for_each = var.ipv4_address != "" ? [1] : []
    content {
      name = "eth0"
      type = "nic"
      properties = {
        network        = var.network_name
        "ipv4.address" = var.ipv4_address
      }
    }
  }

  # Ignore image changes to prevent replacement when importing existing instances
  lifecycle {
    ignore_changes = [image]
  }
}
