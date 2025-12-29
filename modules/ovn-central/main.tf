# =============================================================================
# OVN Central Module
# =============================================================================
# Deploys OVN Central (northbound + southbound databases) in a container
# This provides the OVN control plane for IncusOS chassis nodes to connect to
#
# The container runs:
# - ovn-northbound (ovsdb-server on port 6641)
# - ovn-southbound (ovsdb-server on port 6642)
# - ovn-northd (connects NB and SB databases)

locals {
  # Cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    northbound_port = var.northbound_port
    southbound_port = var.southbound_port
  })
}

# Service-specific profile
# NOTE: This profile includes the network device directly because ovn-central
# must run on a non-OVN network (incusbr0) before OVN networks can be created.
# This breaks the chicken-and-egg dependency.
resource "incus_profile" "ovn_central" {
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

  # Network device - connects to incusbr0 directly (not OVN network)
  device {
    name = "eth0"
    type = "nic"
    properties = {
      network = var.network_name
    }
  }

  # Persistent storage for OVN databases
  dynamic "device" {
    for_each = var.enable_data_persistence ? [1] : []
    content {
      name = "ovn-data"
      type = "disk"
      properties = {
        source = incus_storage_volume.ovn_data[0].name
        pool   = var.storage_pool
        path   = "/var/lib/ovn"
      }
    }
  }

  # Proxy devices to expose OVN ports on the host's physical network
  # This allows IncusOS chassis on other nodes to connect to the central databases
  device {
    name = "ovn-nb-proxy"
    type = "proxy"
    properties = {
      listen  = "tcp:0.0.0.0:${var.northbound_port}"
      connect = "tcp:127.0.0.1:${var.northbound_port}"
    }
  }

  device {
    name = "ovn-sb-proxy"
    type = "proxy"
    properties = {
      listen  = "tcp:0.0.0.0:${var.southbound_port}"
      connect = "tcp:127.0.0.1:${var.southbound_port}"
    }
  }
}

# Storage volume for OVN database persistence
# On clusters, the volume must be on the same node as the instance
resource "incus_storage_volume" "ovn_data" {
  count = var.enable_data_persistence ? 1 : 0

  name   = var.data_volume_name
  pool   = var.storage_pool
  type   = "custom"
  target = var.target_node != "" ? var.target_node : null

  config = {
    "size" = var.data_volume_size
  }
}

# OVN Central instance
resource "incus_instance" "ovn_central" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.ovn_central.name])

  # Pin to specific cluster node if specified (for HA, run on leader node)
  target = var.target_node != "" ? var.target_node : null

  config = {
    "security.privileged"  = "false"
    "cloud-init.user-data" = local.cloud_init_content
  }

  depends_on = [
    incus_storage_volume.ovn_data
  ]
}
