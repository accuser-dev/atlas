resource "incus_profile" "caddy" {
  name = var.profile_name

  config = {
    "limits.cpu"    = var.cpu_limit
    "limits.memory" = var.memory_limit
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
      network = var.production_network
    }
  }

  device {
    name = "eth1"
    type = "nic"
    properties = {
      network = var.management_network
    }
  }

  device {
    name = "eth2"
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
  profiles = ["default", incus_profile.caddy.name]

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
}
