# =============================================================================
# Cloudflared Module
# =============================================================================
# Deploys Cloudflare Tunnel client for secure remote access via Zero Trust
# Uses Alpine Linux system container with cloud-init for configuration

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    tunnel_token        = var.tunnel_token
    metrics_port        = var.metrics_port
    cloudflared_version = var.cloudflared_version
  })
}

# Service-specific profile
# Contains resource limits and root disk with size limit
# Base infrastructure (network) is provided by profiles passed via var.profiles
resource "incus_profile" "cloudflared" {
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

resource "incus_instance" "cloudflared" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.cloudflared.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  # Ignore image changes to prevent replacement when importing existing instances
  lifecycle {
    ignore_changes = [image]
  }
}
