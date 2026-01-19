# =============================================================================
# Network ACLs for Microsegmentation
# =============================================================================
# Defines network access control lists for OVN networks.
# Initially deployed in logging mode (state = "logged") to monitor traffic
# patterns before enforcing rules.
#
# Migration path:
# 1. Deploy with state = "logged" (current)
# 2. Monitor logs: journalctl -t ovn-controller | grep ACL
# 3. Verify expected traffic patterns
# 4. Change to state = "enabled" for enforcement
# =============================================================================

# -----------------------------------------------------------------------------
# Management Network ACL
# -----------------------------------------------------------------------------
# Controls traffic to/from monitoring services (Prometheus, Alertmanager, Alloy)

module "management_acl" {
  source = "../../modules/network-acl"

  count = var.network_backend == "ovn" ? 1 : 0

  name        = "management-acl"
  description = "ACL for management network - monitoring services"

  ingress_rules = [
    # Allow Prometheus scraping from within network
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "9090"
      description      = "Prometheus scraping (internal)"
      state            = "logged"
    },
    # Allow external Prometheus federation (from iapetus)
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "9090"
      description      = "Prometheus federation (external)"
      state            = "logged"
    },
    # Allow Alertmanager web UI and API
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "9093"
      description      = "Alertmanager (internal)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "9093"
      description      = "Alertmanager (external)"
      state            = "logged"
    },
    # Allow Alloy metrics and log receivers
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "12345"
      description      = "Alloy metrics (internal)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@external"
      protocol         = "udp"
      destination_port = "1514"
      description      = "Alloy syslog receiver (external)"
      state            = "logged"
    },
    # Allow OVN Central metrics
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "9476"
      description      = "OVN metrics (internal)"
      state            = "logged"
    },
    # Allow ICMP for diagnostics
    {
      action      = "allow"
      protocol    = "icmp4"
      description = "ICMP ping"
      state       = "logged"
    },
    # Default deny - log all other ingress
    {
      action      = "drop"
      description = "Default deny ingress"
      state       = "logged"
    }
  ]

  egress_rules = [
    # Allow DNS queries
    {
      action           = "allow"
      protocol         = "udp"
      destination_port = "53"
      description      = "DNS queries"
      state            = "logged"
    },
    {
      action           = "allow"
      protocol         = "tcp"
      destination_port = "53"
      description      = "DNS queries (TCP)"
      state            = "logged"
    },
    # Allow Alloy to ship logs to Loki (iapetus)
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "tcp"
      destination_port = "3100"
      description      = "Loki log shipping"
      state            = "logged"
    },
    # Allow Prometheus to scrape targets
    {
      action      = "allow"
      destination = "@internal"
      protocol    = "tcp"
      description = "Prometheus scraping targets"
      state       = "logged"
    },
    # Allow HTTPS for external APIs (Forgejo, package downloads)
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "tcp"
      destination_port = "443"
      description      = "HTTPS to external services"
      state            = "logged"
    },
    # Allow HTTP for package downloads
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "tcp"
      destination_port = "80"
      description      = "HTTP to external services"
      state            = "logged"
    },
    # Allow ICMP for diagnostics
    {
      action      = "allow"
      protocol    = "icmp4"
      description = "ICMP ping"
      state       = "logged"
    },
    # Default deny - log all other egress
    {
      action      = "drop"
      description = "Default deny egress"
      state       = "logged"
    }
  ]
}

# -----------------------------------------------------------------------------
# Production Network ACL
# -----------------------------------------------------------------------------
# Controls traffic to/from public-facing services (Mosquitto, CoreDNS)

module "production_acl" {
  source = "../../modules/network-acl"

  count = var.network_backend == "ovn" ? 1 : 0

  name        = "production-acl"
  description = "ACL for production network - public services"

  ingress_rules = [
    # Allow MQTT traffic (Mosquitto)
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "1883"
      description      = "MQTT (external)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "8883"
      description      = "MQTTS (external)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "1883"
      description      = "MQTT (internal)"
      state            = "logged"
    },
    # Allow DNS traffic (CoreDNS)
    {
      action           = "allow"
      source           = "@external"
      protocol         = "udp"
      destination_port = "53"
      description      = "DNS UDP (external)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "53"
      description      = "DNS TCP (external)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "udp"
      destination_port = "53"
      description      = "DNS UDP (internal)"
      state            = "logged"
    },
    # Allow CoreDNS metrics scraping
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "9153"
      description      = "CoreDNS metrics"
      state            = "logged"
    },
    # Allow Mosquitto metrics scraping
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "9001"
      description      = "Mosquitto metrics"
      state            = "logged"
    },
    # Allow PostgreSQL connections (from Forgejo)
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "5432"
      description      = "PostgreSQL (internal)"
      state            = "logged"
    },
    # Allow PostgreSQL metrics scraping
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "9187"
      description      = "PostgreSQL metrics (internal)"
      state            = "logged"
    },
    # Allow Forgejo HTTP (web UI)
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "3000"
      description      = "Forgejo HTTP (internal)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "3000"
      description      = "Forgejo HTTP (external)"
      state            = "logged"
    },
    # Allow Forgejo SSH (git operations)
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "22"
      description      = "Forgejo SSH (internal)"
      state            = "logged"
    },
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "22"
      description      = "Forgejo SSH (external)"
      state            = "logged"
    },
    # Allow ICMP for diagnostics
    {
      action      = "allow"
      protocol    = "icmp4"
      description = "ICMP ping"
      state       = "logged"
    },
    # Default deny - log all other ingress
    {
      action      = "drop"
      description = "Default deny ingress"
      state       = "logged"
    }
  ]

  egress_rules = [
    # Allow DNS queries (for CoreDNS forwarding)
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "udp"
      destination_port = "53"
      description      = "DNS forwarding"
      state            = "logged"
    },
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "tcp"
      destination_port = "53"
      description      = "DNS forwarding (TCP)"
      state            = "logged"
    },
    # Allow internal communication
    {
      action      = "allow"
      destination = "@internal"
      description = "Internal communication"
      state       = "logged"
    },
    # Allow HTTPS for external APIs (Forgejo webhooks, mirrors)
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "tcp"
      destination_port = "443"
      description      = "HTTPS to external services"
      state            = "logged"
    },
    # Allow HTTP for package downloads
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "tcp"
      destination_port = "80"
      description      = "HTTP to external services"
      state            = "logged"
    },
    # Allow Forgejo SSH to external git remotes
    {
      action           = "allow"
      destination      = "@external"
      protocol         = "tcp"
      destination_port = "22"
      description      = "SSH to external git remotes"
      state            = "logged"
    },
    # Allow ICMP for diagnostics
    {
      action      = "allow"
      protocol    = "icmp4"
      description = "ICMP ping"
      state       = "logged"
    },
    # Default deny - log all other egress
    {
      action      = "drop"
      description = "Default deny egress"
      state       = "logged"
    }
  ]
}
