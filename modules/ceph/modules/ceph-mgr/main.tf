# =============================================================================
# Ceph MGR Submodule
# =============================================================================
# Deploys a Ceph Manager daemon in a Debian Trixie container.
# MGR provides monitoring, orchestration, and REST API functionality.
# Requires at least one MON to be running first.

locals {
  # Cluster network defaults to public network if not specified
  cluster_network = var.cluster_network != "" ? var.cluster_network : var.public_network

  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    cluster_name        = var.cluster_name
    cluster_fsid        = var.cluster_fsid
    mgr_id              = var.mgr_id
    mon_initial_members = var.mon_initial_members
    mon_host            = var.mon_host
    public_network      = var.public_network
    cluster_network     = local.cluster_network
    enable_dashboard    = var.enable_dashboard
    dashboard_port      = var.dashboard_port
    enable_prometheus   = var.enable_prometheus
    prometheus_port     = var.prometheus_port
  })
}

# -----------------------------------------------------------------------------
# Service Profile
# -----------------------------------------------------------------------------

resource "incus_profile" "ceph_mgr" {
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
# MGR Instance
# -----------------------------------------------------------------------------

resource "incus_instance" "ceph_mgr" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.ceph_mgr.name])

  # Pin to specific cluster node
  target = var.target_node != "" ? var.target_node : null

  config = {
    "security.privileged"  = "false"
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [incus_profile.ceph_mgr]
}
