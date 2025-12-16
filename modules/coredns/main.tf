# =============================================================================
# CoreDNS Module
# =============================================================================
# Provides split-horizon DNS for internal service resolution.
# Zone file is generated from dns_records collected from service modules.
#
# Uses a system container (images:alpine) instead of OCI application container
# because LXC requires a proper filesystem structure that OCI containers lack.

# Service-specific profile
# Contains resource limits, root disk with size limit, and service-specific devices (proxy devices for DNS)
# Network connectivity is provided by profiles passed via var.profiles
resource "incus_profile" "coredns" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
    "boot.autostart"        = "true"
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

  # External access via proxy device for DNS (UDP)
  # Only enabled in bridge mode - physical mode gets direct LAN IP
  dynamic "device" {
    for_each = var.enable_external_access ? [1] : []
    content {
      name = "dns-udp-proxy"
      type = "proxy"
      properties = {
        listen  = "udp:0.0.0.0:${var.external_dns_port}"
        connect = "udp:127.0.0.1:${var.dns_port}"
        bind    = "host"
      }
    }
  }

  # External access via proxy device for DNS (TCP)
  # DNS requires both UDP and TCP on port 53
  dynamic "device" {
    for_each = var.enable_external_access ? [1] : []
    content {
      name = "dns-tcp-proxy"
      type = "proxy"
      properties = {
        listen  = "tcp:0.0.0.0:${var.external_dns_port}"
        connect = "tcp:127.0.0.1:${var.dns_port}"
        bind    = "host"
      }
    }
  }
}

locals {
  # Combine service module records with additional static records
  all_dns_records = concat(var.dns_records, var.additional_records)

  # Generate zone serial in YYYYMMDDNN format
  # Using timestamp ensures serial increases on each apply
  zone_serial = formatdate("YYYYMMDD", timestamp())

  # Generate Corefile content
  corefile_content = templatefile("${path.module}/templates/Corefile.tftpl", {
    domain               = var.domain
    dns_port             = var.dns_port
    health_port          = var.health_port
    incus_dns_server     = var.incus_dns_server
    upstream_dns_servers = var.upstream_dns_servers
  })

  # Generate zone file content
  # Note: NS record uses the instance name with .incus suffix for resolution
  # This avoids a circular dependency with ipv4_address
  zone_file_content = templatefile("${path.module}/templates/zone.tftpl", {
    domain         = var.domain
    soa_nameserver = var.soa_nameserver
    soa_admin      = var.soa_admin
    zone_ttl       = var.zone_ttl
    serial         = "${local.zone_serial}01"
    nameserver_ip  = var.nameserver_ip
    dns_records    = local.all_dns_records
  })

  # Generate cloud-init configuration
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    corefile_content  = local.corefile_content
    zone_file_content = local.zone_file_content
    domain            = var.domain
  })
}

resource "incus_instance" "coredns" {
  name     = var.instance_name
  image    = var.image
  type     = "container"
  profiles = concat(var.profiles, [incus_profile.coredns.name])

  config = {
    "cloud-init.user-data" = local.cloud_init_content
  }
}
