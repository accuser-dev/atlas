# =============================================================================
# Cluster Nodes
# =============================================================================

output "cluster_nodes" {
  description = "List of cluster node names (discovered from Incus API)"
  value       = local.cluster_nodes
}

# =============================================================================
# Network Configuration
# =============================================================================

output "production_network_type" {
  description = "Production network type (bridge or physical)"
  value       = module.base.production_network_type
}

output "production_network_is_physical" {
  description = "Whether production network is physical (direct LAN attachment)"
  value       = module.base.production_network_is_physical
}

# =============================================================================
# Service Endpoints
# =============================================================================

output "prometheus_endpoint" {
  description = "Prometheus endpoint URL (for iapetus federation)"
  value       = module.prometheus01.prometheus_endpoint
}

output "alertmanager_endpoint" {
  description = "Alertmanager endpoint URL"
  value       = module.alertmanager01.alertmanager_endpoint
}

output "mosquitto_mqtt_endpoint" {
  description = "Internal MQTT endpoint URL"
  value       = module.mosquitto01.mqtt_endpoint
}

output "mosquitto_external_ports" {
  description = "External host ports for MQTT access"
  value = {
    mqtt  = module.mosquitto01.external_mqtt_port
    mqtts = module.mosquitto01.external_mqtts_port
  }
}

# =============================================================================
# DNS Configuration
# =============================================================================

output "coredns_dns_endpoint" {
  description = "Internal DNS endpoint"
  value       = module.coredns01.dns_endpoint
}

output "coredns_ipv4_address" {
  description = "CoreDNS IPv4 address"
  value       = module.coredns01.ipv4_address
}

output "coredns_external_port" {
  description = "External DNS port on host (bridge mode only)"
  value       = module.coredns01.external_dns_port
}

# =============================================================================
# Incus Metrics
# =============================================================================

output "incus_metrics_endpoint" {
  description = "Incus metrics endpoint URL"
  value       = var.enable_incus_metrics ? "https://${var.incus_metrics_address}/1.0/metrics" : null
}

output "incus_metrics_certificate_fingerprint" {
  description = "Fingerprint of the metrics certificate"
  value       = var.enable_incus_metrics ? module.incus_metrics[0].certificate_fingerprint : null
}

# =============================================================================
# Log Shipping
# =============================================================================

output "alloy_endpoint" {
  description = "Alloy HTTP API endpoint URL"
  value       = module.alloy01.alloy_endpoint
}

output "alloy_loki_target" {
  description = "Loki URL that Alloy is shipping logs to"
  value       = module.alloy01.loki_target
}

output "alloy_syslog_endpoint" {
  description = "Syslog receiver endpoint (UDP) - configure IncusOS hosts to send logs here"
  value       = module.alloy01.syslog_endpoint
}

# =============================================================================
# PostgreSQL Database
# =============================================================================

output "postgresql_endpoint" {
  description = "PostgreSQL connection endpoint"
  value       = var.enable_postgresql ? module.postgresql01[0].postgresql_endpoint : null
}

output "postgresql_ipv4_address" {
  description = "PostgreSQL container IPv4 address"
  value       = var.enable_postgresql ? module.postgresql01[0].ipv4_address : null
}

output "postgresql_metrics_endpoint" {
  description = "PostgreSQL Prometheus metrics endpoint"
  value       = var.enable_postgresql ? module.postgresql01[0].metrics_endpoint : null
}

# =============================================================================
# Forgejo Git Forge
# =============================================================================

output "forgejo_http_endpoint" {
  description = "Forgejo web UI endpoint"
  value       = var.enable_forgejo ? module.forgejo01[0].http_endpoint : null
}

output "forgejo_ssh_endpoint" {
  description = "Forgejo SSH endpoint for git operations"
  value       = var.enable_forgejo ? module.forgejo01[0].ssh_endpoint : null
}

output "forgejo_ssh_clone_url" {
  description = "SSH clone URL format (git@host:owner/repo.git)"
  value       = var.enable_forgejo ? module.forgejo01[0].ssh_clone_url : null
}

output "forgejo_metrics_endpoint" {
  description = "Forgejo Prometheus metrics endpoint"
  value       = var.enable_forgejo ? module.forgejo01[0].metrics_endpoint : null
}

# =============================================================================
# Ansible Integration Outputs (Hybrid Terraform + Ansible)
# =============================================================================

# Forgejo Runner
output "forgejo_runner_instances" {
  description = "Forgejo runner instances for Ansible inventory"
  value = var.enable_forgejo_runner ? {
    "forgejo-runner01" = module.forgejo_runner01[0].instance_info
  } : {}
}

output "forgejo_runner_ansible_vars" {
  description = "Variables passed to Ansible for runner configuration"
  value       = var.enable_forgejo_runner ? module.forgejo_runner01[0].ansible_vars : null
}

# Prometheus
output "prometheus_instances" {
  description = "Prometheus instances for Ansible inventory"
  value = {
    "prometheus01" = module.prometheus01.instance_info
  }
}

output "prometheus_ansible_vars" {
  description = "Variables passed to Ansible for Prometheus configuration"
  sensitive   = true
  value       = module.prometheus01.ansible_vars
}

# Alertmanager
output "alertmanager_instances" {
  description = "Alertmanager instances for Ansible inventory"
  value = {
    "alertmanager01" = module.alertmanager01.instance_info
  }
}

output "alertmanager_ansible_vars" {
  description = "Variables passed to Ansible for Alertmanager configuration"
  sensitive   = true
  value       = module.alertmanager01.ansible_vars
}

# Mosquitto
output "mosquitto_instances" {
  description = "Mosquitto instances for Ansible inventory"
  value = {
    "mosquitto01" = module.mosquitto01.instance_info
  }
}

output "mosquitto_ansible_vars" {
  description = "Variables passed to Ansible for Mosquitto configuration"
  sensitive   = true
  value       = module.mosquitto01.ansible_vars
}

# PostgreSQL
output "postgresql_instances" {
  description = "PostgreSQL instances for Ansible inventory"
  value = var.enable_postgresql ? {
    "postgresql01" = module.postgresql01[0].instance_info
  } : {}
}

output "postgresql_ansible_vars" {
  description = "Variables passed to Ansible for PostgreSQL configuration"
  sensitive   = true
  value       = var.enable_postgresql ? module.postgresql01[0].ansible_vars : null
}

# Forgejo
output "forgejo_instances" {
  description = "Forgejo instances for Ansible inventory"
  value = var.enable_forgejo ? {
    "forgejo01" = module.forgejo01[0].instance_info
  } : {}
}

output "forgejo_ansible_vars" {
  description = "Variables passed to Ansible for Forgejo configuration"
  sensitive   = true
  value       = var.enable_forgejo ? module.forgejo01[0].ansible_vars : null
}

# =============================================================================
# OVN Configuration
# =============================================================================

output "cluster_ips" {
  description = "List of cluster node IP addresses (discovered from Incus API)"
  value       = local.cluster_ips
}

output "ovn_central_ipv4_address" {
  description = "IPv4 address of the OVN Central container"
  value       = var.network_backend == "ovn" ? module.ovn_central[0].ipv4_address : null
}

output "ovn_central_northbound_connection" {
  description = "OVN northbound connection string (points to ovn-central container)"
  value       = var.network_backend == "ovn" ? module.ovn_central[0].northbound_connection : null
}

output "ovn_central_southbound_connection" {
  description = "OVN southbound connection string (for chassis configuration)"
  value       = var.network_backend == "ovn" ? module.ovn_central[0].southbound_connection : null
}

output "network_backend" {
  description = "Network backend in use (bridge or ovn)"
  value       = var.network_backend
}

# =============================================================================
# OVN Load Balancer VIPs
# =============================================================================

output "mosquitto_lb_address" {
  description = "OVN load balancer VIP for Mosquitto (LAN-routable)"
  value       = var.network_backend == "ovn" && var.mosquitto_lb_address != "" ? var.mosquitto_lb_address : null
}

output "coredns_lb_address" {
  description = "OVN load balancer VIP for CoreDNS (LAN-routable)"
  value       = var.network_backend == "ovn" && var.coredns_lb_address != "" ? var.coredns_lb_address : null
}

output "alloy_syslog_lb_address" {
  description = "OVN load balancer VIP for Alloy syslog receiver (LAN-routable, UDP:1514)"
  value       = var.network_backend == "ovn" && var.alloy_syslog_lb_address != "" ? var.alloy_syslog_lb_address : null
}

output "prometheus_lb_address" {
  description = "OVN load balancer VIP for Prometheus (LAN-routable, for federation from iapetus)"
  value       = var.network_backend == "ovn" && var.prometheus_lb_address != "" ? var.prometheus_lb_address : null
}

output "forgejo_lb_address" {
  description = "OVN load balancer VIP for Forgejo (LAN-routable)"
  value       = var.network_backend == "ovn" && var.enable_forgejo && var.forgejo_lb_address != "" ? var.forgejo_lb_address : null
}

output "forgejo_lb_https_endpoint" {
  description = "Forgejo web UI HTTPS endpoint via OVN load balancer (LAN-routable)"
  value       = var.network_backend == "ovn" && var.enable_forgejo && var.forgejo_lb_address != "" ? "https://${var.forgejo_lb_address}" : null
}

output "forgejo_lb_ssh_endpoint" {
  description = "Forgejo SSH endpoint via OVN load balancer (LAN-routable)"
  value       = var.network_backend == "ovn" && var.enable_forgejo && var.forgejo_lb_address != "" ? "ssh://git@${var.forgejo_lb_address}:22" : null
}

output "ceph_rgw_lb_address" {
  description = "OVN load balancer VIP for Ceph RGW S3 API (LAN-routable)"
  value       = var.network_backend == "ovn" && var.enable_ceph && var.ceph_rgw_lb_address != "" ? var.ceph_rgw_lb_address : null
}

output "ceph_rgw_lb_endpoint" {
  description = "Ceph RGW S3 API endpoint via OVN load balancer (LAN-routable)"
  value       = var.network_backend == "ovn" && var.enable_ceph && var.ceph_rgw_lb_address != "" ? "http://${var.ceph_rgw_lb_address}:7480" : null
}

# =============================================================================
# Ceph Storage
# =============================================================================

output "ceph_cluster_fsid" {
  description = "Ceph cluster FSID"
  value       = var.enable_ceph ? module.ceph[0].cluster_fsid : null
}

output "ceph_mon_endpoints" {
  description = "List of Ceph MON endpoints"
  value       = var.enable_ceph ? module.ceph[0].mon_endpoints : null
}

output "ceph_s3_endpoint" {
  description = "Ceph S3 API endpoint (RGW)"
  value       = var.enable_ceph ? module.ceph[0].primary_s3_endpoint : null
}

output "ceph_mgr_prometheus_endpoints" {
  description = "Ceph MGR Prometheus metrics endpoints"
  value       = var.enable_ceph ? module.ceph[0].mgr_prometheus_endpoints : null
}

# =============================================================================
# Managed Resources (for Makefile dynamic discovery)
# =============================================================================
# Maps Incus resource names to their Terraform state paths
# Used by import/clean-incus targets to avoid hardcoded resource lists

output "managed_resources" {
  description = "Resource mappings for Makefile discovery (Incus name -> Terraform path)"
  value = {
    # Profiles: Map Incus profile name -> Terraform import path
    profiles = merge(
      { "prometheus" = "module.prometheus01.incus_profile.prometheus" },
      { "alertmanager" = "module.alertmanager01.incus_profile.alertmanager" },
      { "mosquitto" = "module.mosquitto01.incus_profile.mosquitto" },
      { "coredns" = "module.coredns01.incus_profile.coredns" },
      { "alloy" = "module.alloy01.incus_profile.alloy" },
      var.network_backend == "ovn" ? { "ovn-central" = "module.ovn_central[0].incus_profile.ovn_central" } : {},
      var.enable_postgresql ? { "postgresql" = "module.postgresql01[0].incus_profile.postgresql" } : {},
      var.enable_forgejo ? { "forgejo" = "module.forgejo01[0].incus_profile.forgejo" } : {},
      var.enable_forgejo_runner ? { "forgejo-runner" = "module.forgejo_runner01[0].incus_profile.forgejo_runner" } : {},
    )

    # Instances: Map Incus instance name -> Terraform import path
    instances = merge(
      { "prometheus01" = "module.prometheus01.incus_instance.prometheus" },
      { "alertmanager01" = "module.alertmanager01.incus_instance.alertmanager" },
      { "mosquitto01" = "module.mosquitto01.incus_instance.mosquitto" },
      { "coredns01" = "module.coredns01.incus_instance.coredns" },
      { "alloy01" = "module.alloy01.incus_instance.alloy" },
      var.network_backend == "ovn" ? { "ovn-central01" = "module.ovn_central[0].incus_instance.ovn_central" } : {},
      var.enable_postgresql ? { "postgresql01" = "module.postgresql01[0].incus_instance.postgresql" } : {},
      var.enable_forgejo ? { "forgejo01" = "module.forgejo01[0].incus_instance.forgejo" } : {},
      var.enable_forgejo_runner ? { "forgejo-runner01" = "module.forgejo_runner01[0].incus_instance.forgejo_runner" } : {},
    )

    # Volumes: Map Incus volume name -> Terraform import path
    volumes = merge(
      { "prometheus01-data" = "module.prometheus01.incus_storage_volume.prometheus_data[0]" },
      { "alertmanager01-data" = "module.alertmanager01.incus_storage_volume.alertmanager_data[0]" },
      { "mosquitto01-data" = "module.mosquitto01.incus_storage_volume.mosquitto_data[0]" },
      var.network_backend == "ovn" ? { "ovn-central01-data" = "module.ovn_central[0].incus_storage_volume.ovn_central_data[0]" } : {},
      var.enable_postgresql ? { "postgresql01-data" = "module.postgresql01[0].incus_storage_volume.postgresql_data[0]" } : {},
      var.enable_forgejo ? { "forgejo01-data" = "module.forgejo01[0].incus_storage_volume.forgejo_data[0]" } : {},
      var.enable_forgejo_runner ? { "forgejo-runner01-data" = "module.forgejo_runner01[0].incus_storage_volume.forgejo_runner_data[0]" } : {},
    )

    # Networks: Map network name -> Terraform import path
    networks = {
      "production" = "module.base.incus_network.production[0]"
      "management" = "module.base.incus_network.management[0]"
    }
  }
}
