# Service-specific profile
# Contains only resource limits and service-specific devices (multi-network setup)
# Base infrastructure (root disk, boot config) is provided by profiles passed via var.profiles
resource "incus_profile" "caddy" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

  # Caddy has a special multi-network setup for reverse proxy functionality
  # Production network (public-facing applications)
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

  # GitOps network (for Atlantis and CI/CD automation)
  dynamic "device" {
    for_each = var.gitops_network != "" ? [1] : []
    content {
      name = "gitops"
      type = "nic"
      properties = {
        network = var.gitops_network
      }
    }
  }

  # External network (for external access, typically incusbr0)
  # Named "eth0" to override the default profile's NIC on incusbr0
  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.external_network
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
