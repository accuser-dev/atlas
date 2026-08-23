# =============================================================================
# Production-Network NIC Pins
# =============================================================================
# iapetus services are moving off the NAT'd "management" bridge (a leftover
# from when OVN was in the picture) and onto eno2/production directly, so
# they're reachable from the LAN - the Deco X50 mesh router provides no DNS
# of its own, so CoreDNS (already on eno2) is becoming the single source of
# truth for both LAN clients and internal service-to-service resolution.
#
# Each service needs a stable MAC so a router-side DHCP reservation keeps its
# IP fixed across a full `tofu destroy`/`apply` rebuild - otherwise Incus
# would generate a new random `volatile.<device>.hwaddr` every time and the
# reservation (and the matching entry in dns_additional_records) would go
# stale. One small profile per service overrides just the `prod` device
# (`network` re-declared alongside `hwaddr` - profile device composition
# replaces the whole device, not a per-key merge; verified this session
# against a throwaway instance before relying on it here).
#
# IP/MAC allocation lives in terraform.tfvars (dns_additional_records) and
# the DHCP reservations the operator sets on the router after `tofu apply`
# reports each instance's actual MAC.

resource "incus_profile" "grafana01_nic_pin" {
  name = "grafana01-nic-pin"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = module.base.production_network_name
      hwaddr  = "10:66:6a:00:00:15"
    }
  }
}

resource "incus_profile" "prometheus01_nic_pin" {
  name = "prometheus01-nic-pin"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = module.base.production_network_name
      hwaddr  = "10:66:6a:00:00:16"
    }
  }
}

resource "incus_profile" "loki01_nic_pin" {
  name = "loki01-nic-pin"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = module.base.production_network_name
      hwaddr  = "10:66:6a:00:00:17"
    }
  }
}

resource "incus_profile" "step_ca01_nic_pin" {
  name = "step-ca01-nic-pin"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = module.base.production_network_name
      hwaddr  = "10:66:6a:00:00:18"
    }
  }
}

resource "incus_profile" "openfga01_nic_pin" {
  name = "openfga01-nic-pin"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = module.base.production_network_name
      hwaddr  = "10:66:6a:00:00:19"
    }
  }
}

resource "incus_profile" "dex01_nic_pin" {
  name = "dex01-nic-pin"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = module.base.production_network_name
      hwaddr  = "10:66:6a:00:00:20"
    }
  }
}

resource "incus_profile" "cloudflared01_nic_pin" {
  name = "cloudflared01-nic-pin"

  device {
    name = "prod"
    type = "nic"
    properties = {
      network = module.base.production_network_name
      hwaddr  = "10:66:6a:00:00:21"
    }
  }
}
