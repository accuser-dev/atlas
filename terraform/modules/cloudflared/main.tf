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

  config = merge(
    { for k, v in var.environment_variables : "environment.${k}" => v },
    {
      "environment.TUNNEL_TOKEN" = var.tunnel_token
    },
  )
}
