resource "incus_profile" "cloudflared" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
    "boot.autorestart"      = "true"
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
      network = var.network_name
    }
  }
}

resource "incus_instance" "cloudflared" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = ["default", incus_profile.cloudflared.name]

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
    {
      "environment.TUNNEL_TOKEN" = var.tunnel_token
    },
  )
}
