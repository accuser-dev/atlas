# =============================================================================
# Forgejo Git Forge Module
# =============================================================================
# Deploys Forgejo as a system container with PostgreSQL backend.
# Uses Debian Trixie with cloud-init for configuration.

locals {
  # Construct root URL if not provided
  # Use https:// scheme when TLS is enabled
  default_scheme = var.enable_tls ? "https" : "http"
  default_port   = var.enable_tls ? (var.http_port == "443" ? "" : ":${var.http_port}") : ":${var.http_port}"
  root_url       = var.root_url != "" ? var.root_url : "${local.default_scheme}://${var.domain}${local.default_port}/"

  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    forgejo_version   = var.forgejo_version
    http_port         = var.http_port
    ssh_port          = var.ssh_port
    domain            = var.domain
    root_url          = local.root_url
    app_name          = var.app_name
    admin_username    = var.admin_username
    admin_password    = var.admin_password
    admin_email       = var.admin_email
    database_type     = var.database_type
    database_host     = var.database_host
    database_port     = var.database_port
    database_name     = var.database_name
    database_user     = var.database_user
    database_password = var.database_password
    enable_ssh_access = var.enable_ssh_access
    enable_metrics    = var.enable_metrics
    metrics_token     = var.metrics_token
    enable_tls        = var.enable_tls
    tls_certificate   = var.tls_certificate
    tls_private_key   = var.tls_private_key
  })
}

# =============================================================================
# Storage Volume
# =============================================================================

resource "incus_storage_volume" "forgejo_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"
  target  = var.target_node

  config = merge(
    {
      size = var.data_volume_size
      # Forgejo runs as git user (UID/GID will be set during setup)
      "initial.uid"  = "1000"
      "initial.gid"  = "1000"
      "initial.mode" = "0750"
    },
    var.enable_snapshots ? {
      "snapshots.schedule" = var.snapshot_schedule
      "snapshots.expiry"   = var.snapshot_expiry
      "snapshots.pattern"  = var.snapshot_pattern
    } : {}
  )

  content_type = "filesystem"
}

# =============================================================================
# Profile
# =============================================================================

resource "incus_profile" "forgejo" {
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

  # Data volume mount
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "forgejo-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.forgejo_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/forgejo"
      }
    }
  }

  # External SSH proxy device (bridge mode only)
  dynamic "device" {
    for_each = var.enable_external_ssh && !var.use_ovn_lb ? [1] : []
    content {
      name = "ssh-proxy"
      type = "proxy"
      properties = {
        listen  = "tcp:0.0.0.0:${var.external_ssh_port}"
        connect = "tcp:127.0.0.1:${var.ssh_port}"
        bind    = "host"
      }
    }
  }

  # Secondary network for database connectivity (when DB is on different network)
  dynamic "device" {
    for_each = var.database_network != "" ? [1] : []
    content {
      name = "eth1"
      type = "nic"
      properties = {
        network = var.database_network
        name    = "eth1"
      }
    }
  }
}

# =============================================================================
# Container Instance
# =============================================================================

resource "incus_instance" "forgejo" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.forgejo.name])
  target   = var.target_node

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  lifecycle {
    precondition {
      condition     = var.database_type != "postgres" || (var.database_host != "" && var.database_password != "")
      error_message = "When database_type is 'postgres', both database_host and database_password must be provided."
    }
  }

  depends_on = [
    incus_profile.forgejo,
    incus_storage_volume.forgejo_data
  ]
}
