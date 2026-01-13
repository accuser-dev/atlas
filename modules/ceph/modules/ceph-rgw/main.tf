# =============================================================================
# Ceph RGW Submodule
# =============================================================================
# Deploys a Ceph RADOS Gateway daemon in a Debian Trixie container.
# RGW provides S3-compatible and Swift-compatible object storage API.

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    cluster_name         = var.cluster_name
    cluster_fsid         = var.cluster_fsid
    rgw_id               = var.rgw_id
    mon_initial_members  = var.mon_initial_members
    mon_host             = var.mon_host
    public_network       = var.public_network
    rgw_port             = var.rgw_port
    rgw_thread_pool_size = var.rgw_thread_pool_size
  })
}

# -----------------------------------------------------------------------------
# Service Profile
# -----------------------------------------------------------------------------

resource "incus_profile" "ceph_rgw" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
  }

  # Root disk
  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = var.storage_pool
      size = var.root_disk_size
    }
  }

  # Storage network NIC
  device {
    name = "eth0"
    type = "nic"
    properties = merge(
      { network = var.storage_network_name },
      var.static_ip != null && var.static_ip != "" ? { "ipv4.address" = var.static_ip } : {}
    )
  }
}

# -----------------------------------------------------------------------------
# RGW Instance
# -----------------------------------------------------------------------------

resource "incus_instance" "ceph_rgw" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.ceph_rgw.name])

  # Pin to specific cluster node
  target = var.target_node != "" ? var.target_node : null

  config = {
    "security.privileged"  = "false"
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [incus_profile.ceph_rgw]
}
