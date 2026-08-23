# =============================================================================
# Dex OIDC Identity Provider Module
# =============================================================================
# Deploys Dex as an OpenID Connect identity provider with GitHub connector.
# Uses Debian Trixie system container with cloud-init and systemd for configuration.
#
# Dex acts as a federated OIDC provider, allowing authentication via GitHub
# (or other upstream IdPs) while presenting a unified OIDC interface to clients.

locals {
  # DNS name clients actually connect to, extracted from issuer_url (e.g.
  # "https://dex.accuser.dev/dex" -> "dex.accuser.dev") - requested as an
  # extra SAN on the TLS certificate alongside the instance's own hostname.
  dex_issuer_host = regex("^https?://([^/]+)", var.issuer_url)[0]

  tls_dir       = "/var/dex/tls"
  tls_cert_path = "${local.tls_dir}/dex.crt"
  tls_key_path  = "${local.tls_dir}/dex.key"

  # Generate Dex configuration for Ansible
  dex_config = templatefile("${path.module}/templates/config.yaml.tftpl", {
    issuer_url           = var.issuer_url
    http_port            = var.http_port
    metrics_port         = var.metrics_port
    grpc_port            = var.grpc_port
    github_client_id     = var.github_client_id
    github_client_secret = var.github_client_secret
    github_allowed_orgs  = var.github_allowed_orgs
    static_clients       = var.static_clients
    enable_tls           = var.enable_tls
    tls_cert_path        = local.tls_cert_path
    tls_key_path         = local.tls_key_path
  })

  # Cloud-init configuration (minimal bootstrap only)
  cloud_init_content = file("${path.module}/templates/cloud-init.yaml.tftpl")
}

# Storage volume for Dex data (SQLite database)
resource "incus_storage_volume" "dex_data" {
  count = var.enable_data_persistence ? 1 : 0

  name    = var.data_volume_name
  pool    = var.storage_pool
  project = "default"

  config = {
    size = var.data_volume_size
  }
}

# Service-specific profile
resource "incus_profile" "dex" {
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

  # Persistent data volume
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "dex-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.dex_data[0].name
        pool   = var.storage_pool
        path   = "/var/dex"
      }
    }
  }

  depends_on = [
    incus_storage_volume.dex_data
  ]
}

resource "incus_instance" "dex" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.dex.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }

  lifecycle {
    precondition {
      condition     = !var.enable_tls || (var.stepca_url != "" && var.stepca_fingerprint != "")
      error_message = "When enable_tls is true, both stepca_url and stepca_fingerprint must be provided."
    }
  }

  depends_on = [
    incus_profile.dex,
    incus_storage_volume.dex_data
  ]
}
