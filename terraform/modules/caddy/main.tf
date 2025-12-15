# Service-specific profile
# Contains resource limits, root disk with size limit, and service-specific devices (multi-network setup)
# Network is provided by profiles passed via var.profiles
#
# Network modes:
# - Bridge mode (external_network set): 3 NICs - prod, mgmt, eth0 (external)
# - Physical mode (external_network empty): 2 NICs - prod (provides LAN access), mgmt
resource "incus_profile" "caddy" {
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

  # Caddy has a special multi-network setup for reverse proxy functionality
  # Production network (public-facing applications)
  # In physical mode, this provides direct LAN access
  device {
    name = "prod"
    type = "nic"
    properties = {
      network = var.production_network
    }
  }

  # Management network (internal services like monitoring)
  device {
    name = "mgmt"
    type = "nic"
    properties = {
      network = var.management_network
    }
  }

  # External network (for external access, typically incusbr0)
  # Only added when external_network is set (bridge mode)
  # In physical mode, production network provides external access directly
  dynamic "device" {
    for_each = var.external_network != "" ? [1] : []
    content {
      name = "eth0"
      type = "nic"
      properties = {
        network = var.external_network
      }
    }
  }
}

resource "incus_instance" "caddy" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.caddy.name])

  # Cloudflare API token injected as file for security
  # File-based injection prevents token exposure via `incus info`
  file {
    content     = var.cloudflare_api_token
    target_path = "/etc/caddy/cloudflare_token"
    mode        = "0400" # Read-only for root
    uid         = 0
    gid         = 0
  }

  file {
    content = templatefile("${path.module}/templates/Caddyfile.tftpl", {
      service_blocks = join("\n", var.service_blocks)
    })
    target_path = "/etc/caddy/Caddyfile"
    mode        = "0644"
  }

  # Internal CA certificate for backend TLS connections (optional)
  dynamic "file" {
    for_each = var.internal_ca_certificate != "" ? [1] : []
    content {
      content     = var.internal_ca_certificate
      target_path = "/etc/caddy/internal-ca.crt"
      mode        = "0644"
    }
  }
}
