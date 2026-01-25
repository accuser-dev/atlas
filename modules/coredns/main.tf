# =============================================================================
# CoreDNS Module
# =============================================================================
# Provides split-horizon DNS for internal service resolution.
# Zone file is generated from dns_records collected from service modules.
#
# Uses Debian Trixie system container with cloud-init and systemd for configuration.

# Service-specific profile
# Contains resource limits, root disk with size limit, and service-specific devices (proxy devices for DNS)
# Network connectivity is provided by profiles passed via var.profiles
resource "incus_profile" "coredns" {
  name = var.profile_name

  config = {
    "limits.cpu"            = var.cpu_limit
    "limits.memory"         = var.memory_limit
    "limits.memory.enforce" = "hard"
    # Note: boot.autorestart is provided by the container-base profile
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
  # Disabled when using OVN load balancer or physical network mode
  dynamic "device" {
    for_each = var.enable_external_access && !var.use_ovn_lb ? [1] : []
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
  # Disabled when using OVN load balancer or physical network mode
  dynamic "device" {
    for_each = var.enable_external_access && !var.use_ovn_lb ? [1] : []
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

  # Generate zone serial based on content hash
  # This ensures the serial only changes when zone content actually changes,
  # avoiding unnecessary updates on every apply (which timestamp() would cause)
  # Format: 10-digit number derived from hash, ensuring it's always increasing
  # when content changes (hash provides uniqueness, not ordering)
  zone_content_hash = sha256(jsonencode({
    domain        = var.domain
    nameserver_ip = var.nameserver_ip
    records       = local.all_dns_records
  }))
  # Take first 10 chars of hash and convert to a number for DNS serial format
  zone_serial = format("%010d", parseint(substr(local.zone_content_hash, 0, 8), 16) % 2147483647)

  # Generate Corefile content
  corefile_content = templatefile("${path.module}/templates/Corefile.tftpl", {
    domain                   = var.domain
    dns_port                 = var.dns_port
    health_port              = var.health_port
    incus_dns_server         = var.incus_dns_server
    upstream_dns_servers     = var.upstream_dns_servers
    secondary_zones          = var.secondary_zones
    secondary_zone_cache_ttl = var.secondary_zone_cache_ttl
    forward_zones            = var.forward_zones
    forward_zone_cache_ttl   = var.forward_zone_cache_ttl
  })

  # Generate zone file content
  # Note: NS record uses the instance name with .incus suffix for resolution
  # This avoids a circular dependency with ipv4_address
  zone_file_content = templatefile("${path.module}/templates/zone.tftpl", {
    domain         = var.domain
    soa_nameserver = var.soa_nameserver
    soa_admin      = var.soa_admin
    zone_ttl       = var.zone_ttl
    serial         = local.zone_serial
    nameserver_ip  = var.nameserver_ip
    dns_records    = local.all_dns_records
  })

  # Generate cloud-init configuration (minimal bootstrap + static IP if needed)
  cloud_init_content = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    ipv4_address = var.ipv4_address
    ipv4_gateway = var.ipv4_gateway
    dns_servers  = var.static_ip_dns_servers
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
