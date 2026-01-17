# =============================================================================
# Centralized Service Configuration for Cluster Environment
# =============================================================================

locals {
  # ==========================================================================
  # Common Profile Sets (Phase 2: Reduce duplication)
  # ==========================================================================
  # Standard profile combinations used by service modules

  management_profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  production_profiles = [
    module.base.container_base_profile.name,
    module.base.production_network_profile.name,
  ]

  # ==========================================================================
  # External Access Logic (Phase 2: Reduce duplication)
  # ==========================================================================
  # Common conditions for external access configuration

  bridge_external_access = var.network_backend == "bridge" && !module.base.production_network_is_physical
  use_ovn_lb             = var.network_backend == "ovn"

  # ==========================================================================
  # OVN Load Balancer Configuration (Phase 1: Consolidate LB modules)
  # ==========================================================================
  # Centralized configuration for all OVN load balancers
  # Each entry defines a load balancer with its network, backends, and ports

  ovn_load_balancers = {
    mosquitto = {
      enabled        = var.mosquitto_lb_address != ""
      network        = "production"
      listen_address = var.mosquitto_lb_address
      description    = "OVN load balancer for Mosquitto MQTT broker"
      backends = [{
        name           = "mosquitto01"
        target_address = module.mosquitto01.ipv4_address
        target_port    = 1883
      }]
      ports = [
        { description = "MQTT", protocol = "tcp", listen_port = 1883 },
        { description = "MQTTS", protocol = "tcp", listen_port = 8883 },
      ]
    }

    coredns = {
      enabled        = var.coredns_lb_address != ""
      network        = "production"
      listen_address = var.coredns_lb_address
      description    = "OVN load balancer for CoreDNS"
      backends = [{
        name           = "coredns01"
        target_address = module.coredns01.ipv4_address
        target_port    = 53
      }]
      ports = [
        { description = "DNS over UDP", protocol = "udp", listen_port = 53 },
        { description = "DNS over TCP", protocol = "tcp", listen_port = 53 },
      ]
    }

    alloy_syslog = {
      enabled        = var.alloy_syslog_lb_address != ""
      network        = "management"
      listen_address = var.alloy_syslog_lb_address
      description    = "OVN load balancer for Alloy syslog receiver (IncusOS host logs)"
      backends = [{
        name           = "alloy01"
        target_address = module.alloy01.ipv4_address
        target_port    = 1514
      }]
      ports = [
        { description = "Syslog over UDP", protocol = "udp", listen_port = 1514 },
      ]
    }

    prometheus = {
      enabled        = var.prometheus_lb_address != ""
      network        = "management"
      listen_address = var.prometheus_lb_address
      description    = "OVN load balancer for Prometheus (enables federation from iapetus)"
      backends = [{
        name           = "prometheus01"
        target_address = module.prometheus01.ipv4_address
        target_port    = 9090
      }]
      ports = [
        { description = "Prometheus HTTP", protocol = "tcp", listen_port = 9090 },
      ]
    }
  }

  # ==========================================================================
  # Service Resource Limits
  # ==========================================================================
  # Service resource limits
  # These match the iapetus environment where applicable
  services = {
    prometheus = {
      cpu    = "2"
      memory = "2GB"
      port   = 9090
    }
    alertmanager = {
      cpu    = "1"
      memory = "256MB"
      port   = 9093
    }
    mosquitto = {
      cpu    = "1"
      memory = "256MB"
      port   = 1883
    }
    coredns = {
      cpu    = "1"
      memory = "128MB"
      port   = 53
    }
    alloy = {
      cpu    = "1"
      memory = "256MB"
      port   = 12345
    }
    ceph_mon = {
      cpu    = "2"
      memory = "2GB"
    }
    ceph_mgr = {
      cpu    = "2"
      memory = "1GB"
    }
    ceph_osd = {
      cpu    = "4"
      memory = "4GB"
    }
    ceph_rgw = {
      cpu    = "2"
      memory = "2GB"
    }
  }
}
