# Caddy GitOps Module
# A dedicated Caddy instance for the GitOps network
# Handles Atlantis webhook traffic with GitHub IP allowlisting

# Service-specific profile
# Contains resource limits and network configuration for GitOps traffic
resource "incus_profile" "caddy_gitops" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

  # GitOps network (for Atlantis and CI/CD automation)
  device {
    name = "gitops"
    type = "nic"
    properties = {
      network = var.gitops_network
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

resource "incus_instance" "caddy_gitops" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.caddy_gitops.name])

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
