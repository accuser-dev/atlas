# Network ACL Terraform Module

This module creates Incus network ACLs for microsegmentation of OVN networks.

## Features

- **Ingress/Egress Rules**: Define traffic rules for both directions
- **Logging Mode**: Test rules without enforcement using `state = "logged"`
- **Address Selectors**: Use `@internal`, `@external`, or specific CIDRs
- **Protocol Support**: TCP, UDP, ICMP with port ranges

## Usage

```hcl
module "management_acl" {
  source = "../../modules/network-acl"

  name        = "management-acl"
  description = "ACL for management network"

  ingress_rules = [
    {
      action           = "allow"
      source           = "@internal"
      protocol         = "tcp"
      destination_port = "9090"
      description      = "Allow Prometheus scraping"
      state            = "logged"  # Log only, don't enforce yet
    },
    {
      action           = "allow"
      source           = "@external"
      protocol         = "tcp"
      destination_port = "9090"
      description      = "Allow external Prometheus federation"
      state            = "logged"
    },
    {
      action      = "drop"
      description = "Default deny all other ingress"
      state       = "logged"
    }
  ]

  egress_rules = [
    {
      action      = "allow"
      destination = "@external"
      description = "Allow all outbound traffic"
      state       = "logged"
    }
  ]
}
```

## Rule States

| State | Behavior |
|-------|----------|
| `enabled` | Rule is active and enforced |
| `disabled` | Rule is inactive (ignored) |
| `logged` | Rule matches are logged but traffic is allowed |

Use `logged` state initially to monitor traffic patterns before enforcing rules.

## Address Selectors

| Selector | Meaning |
|----------|---------|
| `@internal` | Traffic from/to other instances on the same network |
| `@external` | Traffic from/to outside the network (LAN, internet) |
| CIDR | Specific IP range (e.g., `10.20.0.0/24`) |
| Instance | Instance name (e.g., `prometheus01`) |

## Applying ACLs to Networks

After creating an ACL, apply it to an OVN network:

```hcl
resource "incus_network" "ovn_management" {
  name = "ovn-management"
  type = "ovn"

  config = {
    "security.acls"         = module.management_acl.name
    "security.acls.default.ingress.action" = "allow"  # Default during logging
    "security.acls.default.egress.action"  = "allow"
    # ...
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `name` | ACL name | `string` | n/a | yes |
| `description` | ACL description | `string` | `""` | no |
| `project` | Incus project | `string` | `"default"` | no |
| `ingress_rules` | List of ingress rules | `list(object)` | `[]` | no |
| `egress_rules` | List of egress rules | `list(object)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| `name` | Name of the created ACL |
| `ingress_rule_count` | Number of ingress rules |
| `egress_rule_count` | Number of egress rules |

## Viewing Logs

To view ACL logs on IncusOS:

```bash
# View OVN ACL logs
journalctl -t ovn-controller | grep ACL

# Or check dmesg for netfilter logs
dmesg | grep -i acl
```

## Migration Path

1. **Phase 1**: Deploy ACLs with `state = "logged"` for all rules
2. **Phase 2**: Monitor logs to verify expected traffic patterns
3. **Phase 3**: Change critical allow rules to `state = "enabled"`
4. **Phase 4**: Change deny rules to `state = "enabled"`

## References

- [Incus Network ACLs](https://linuxcontainers.org/incus/docs/main/howto/network_acls/)
- [OVN ACL Documentation](https://docs.ovn.org/en/latest/ref/ovn-nb.5.html#acl-table)
