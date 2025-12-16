# Cloudflared Terraform Module

This module deploys the Cloudflare Tunnel client (cloudflared) on Incus for secure Zero Trust access to internal services.

## Features

- **Zero Trust Access**: Secure remote access without exposing ports
- **Token-Based Auth**: Managed via Cloudflare dashboard
- **Metrics Endpoint**: Prometheus-compatible metrics for monitoring
- **Lightweight**: Minimal resource requirements
- **Profile Composition**: Works with base-infrastructure module profiles

## Usage

```hcl
module "cloudflared01" {
  source = "./modules/cloudflared"

  count = var.cloudflared_tunnel_token != "" ? 1 : 0

  instance_name = "cloudflared01"
  profile_name  = "cloudflared"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  tunnel_token = var.cloudflared_tunnel_token
}
```

## Prerequisites

### Create a Cloudflare Tunnel

1. Log in to [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/)
2. Navigate to **Access** > **Tunnels**
3. Click **Create a tunnel**
4. Choose **Cloudflared** as the connector
5. Name your tunnel (e.g., "atlas-tunnel")
6. Copy the tunnel token

### Configure Public Hostnames

In the Cloudflare dashboard, configure routes for your services:

| Public Hostname | Service | URL |
|-----------------|---------|-----|
| grafana.example.com | HTTP | http://grafana01.incus:3000 |
| prometheus.example.com | HTTP | http://prometheus01.incus:9090 |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Internet                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Cloudflare Edge                            │
│  (DDoS protection, WAF, Access policies)                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Encrypted tunnel
                            │ (outbound only)
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    cloudflared                               │
│              (management network)                            │
└─────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            ▼               ▼               ▼
      ┌──────────┐   ┌──────────┐   ┌──────────┐
      │ Grafana  │   │Prometheus│   │   Loki   │
      └──────────┘   └──────────┘   └──────────┘
```

## Security Benefits

1. **No Inbound Ports**: All connections are outbound from cloudflared
2. **Cloudflare Access**: Add identity-based access controls
3. **DDoS Protection**: Traffic filtered at Cloudflare edge
4. **WAF Rules**: Apply Web Application Firewall rules
5. **Audit Logs**: Full visibility into access attempts

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the cloudflared instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `tunnel_token` | Cloudflare Tunnel token (sensitive) | `string` | n/a | yes |
| `profiles` | List of Incus profile names to apply | `list(string)` | `["default"]` | no |
| `image` | Container image to use | `string` | `"ghcr:accuser-dev/atlas/cloudflared:latest"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit (e.g., "256MB") | `string` | `"256MB"` | no |
| `metrics_port` | Port for metrics endpoint | `string` | `"2000"` | no |
| `environment_variables` | Additional environment variables | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `profile_name` | Name of the created profile |
| `instance_status` | Status of the instance |
| `metrics_endpoint` | Prometheus metrics endpoint URL |

## Conditional Deployment

The module is typically deployed conditionally based on token availability:

```hcl
# In terraform.tfvars
cloudflared_tunnel_token = "eyJhIjoiYWJjMTIz..."  # Set to enable

# In main.tf
module "cloudflared01" {
  source = "./modules/cloudflared"
  count  = var.cloudflared_tunnel_token != "" ? 1 : 0
  # ...
}
```

## Troubleshooting

### Check tunnel status

```bash
incus exec cloudflared01 -- cloudflared tunnel info
```

### View connection logs

```bash
incus exec cloudflared01 -- cat /var/log/cloudflared.log
```

### Test metrics endpoint

```bash
curl http://cloudflared01.incus:2000/metrics
```

### Verify tunnel connectivity

```bash
# Check if tunnel is connected
incus exec cloudflared01 -- cloudflared tunnel list
```

## Prometheus Integration

Add cloudflared to Prometheus scrape config:

```yaml
scrape_configs:
  - job_name: 'cloudflared'
    static_configs:
      - targets: ['cloudflared01.incus:2000']
        labels:
          service: 'cloudflared'
          instance: 'cloudflared01'
```

## Related Modules

- [caddy](../caddy/) - Alternative for public HTTPS with Let's Encrypt
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Zero Trust Access](https://developers.cloudflare.com/cloudflare-one/policies/access/)
- [Cloudflared Metrics](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/monitor-tunnels/metrics/)
