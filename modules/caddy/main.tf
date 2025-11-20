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
}

resource "incus_instance" "caddy" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default", incus_profile.caddy.name]

  config = {
    "environment.CLOUDFLARE_API_TOKEN" = var.cloudflare_api_token
  }

  file {
    content = templatefile("${path.module}/templates/Caddyfile.tftpl", {
      service_blocks = join("\n", var.service_blocks)
    })
    target_path = "/etc/caddy/Caddyfile"
    mode        = "0644"
  }
}
