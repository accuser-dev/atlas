# Caddy Terraform Module

This module deploys a Caddy reverse proxy on Incus with automatic HTTPS certificate management via Let's Encrypt and Cloudflare DNS.

## Features

- **Automatic HTTPS**: Let's Encrypt certificates with Cloudflare DNS-01 challenge
- **Triple Network Interfaces**: Production, management, and external connectivity
- **Dynamic Configuration**: Caddyfile generated from service module outputs
- **Secure Secret Management**: File-based token injection (not environment variables)
- **Resource Limits**: Configurable CPU and memory constraints

## Usage

```hcl
module "caddy01" {
  source = "./modules/caddy"

  instance_name = "caddy01"
  profile_name  = "caddy01"

  production_network = incus_network.production.name
  management_network = incus_network.management.name
  external_network   = "incusbr0"

  cloudflare_api_token = var.cloudflare_api_token

  service_blocks = [
    module.grafana01.caddy_config_block,
    # Add more service blocks here
  ]
}
```

## Secret Management

### Cloudflare API Token Security

The Cloudflare API token is **injected as a file** rather than an environment variable for enhanced security:

```hcl
file {
  content     = var.cloudflare_api_token
  target_path = "/etc/caddy/cloudflare_token"
  mode        = "0400"  # Read-only for root
  uid         = 0
  gid         = 0
}
```

**Why file-based injection?**

| Method | Visibility | Security |
|--------|-----------|----------|
| Environment variable | `incus info <container>` shows all env vars | ❌ Exposed to anyone with Incus access |
| File with 0400 perms | Only root inside container can read | ✅ Defense-in-depth |

**Caddy Configuration:**
```caddyfile
{
  acme_dns cloudflare {file./etc/caddy/cloudflare_token} {
    resolvers 1.1.1.1
  }
}
```

The `{file./etc/caddy/cloudflare_token}` syntax tells Caddy to read the token from the specified file.

### Best Practices

1. **Never commit tokens** to version control
2. **Use Terraform sensitive variables**:
   ```hcl
   variable "cloudflare_api_token" {
     type      = string
     sensitive = true
   }
   ```
3. **Store in terraform.tfvars** (gitignored):
   ```hcl
   cloudflare_api_token = "your-token-here"
   ```
4. **Use environment variables in CI/CD**:
   ```bash
   export TF_VAR_cloudflare_api_token="your-token"
   ```
5. **Rotate tokens regularly**

### Alternative: Incus Secrets (Future)

When Incus secrets feature becomes available, consider migrating to native secrets management.

## Network Architecture

Caddy has **three network interfaces** for different types of traffic:

```
┌─────────────────────────────┐
│         Caddy               │
│                             │
│  eth0: Production Network   │──> Public-facing services
│  eth1: Management Network   │──> Internal services (Grafana, etc.)
│  eth2: External Bridge      │──> Internet access (HTTPS, DNS)
└─────────────────────────────┘
```

### Network Usage

- **eth0 (Production)**: Routes to services on production network
- **eth1 (Management)**: Routes to monitoring services (Grafana, Prometheus, Loki)
- **eth2 (External)**: Outbound HTTPS for Let's Encrypt, DNS for Cloudflare

## Dynamic Configuration

The Caddyfile is dynamically generated from service module outputs:

```hcl
# Service modules generate their Caddy config blocks
module "grafana01" {
  source = "./modules/grafana"
  # ... configuration
}

# Caddy module collects all service blocks
module "caddy01" {
  service_blocks = [
    module.grafana01.caddy_config_block,
    module.grafana02.caddy_config_block,
  ]
}
```

Each service block contains:
- Domain configuration
- IP allowlist rules
- Security headers
- Reverse proxy target

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Incus instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `production_network` | Production network name | `string` | n/a | yes |
| `management_network` | Management network name | `string` | n/a | yes |
| `external_network` | External network name | `string` | `"incusbr0"` | no |
| `cloudflare_api_token` | Cloudflare API token for DNS | `string` | n/a | yes (sensitive) |
| `service_blocks` | List of Caddyfile service blocks | `list(string)` | n/a | yes |
| `image` | Docker image to use | `string` | `"docker:ghcr.io/accuser/atlas/caddy:latest"` | no |
| `cpu_limit` | CPU limit | `number` | `2` | no |
| `memory_limit` | Memory limit | `string` | `"1GB"` | no |
| `storage_pool` | Storage pool for root disk | `string` | `"local"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | The name of the Caddy instance |

## Security Considerations

1. **Token Permissions**: File is 0400 (read-only for root only)
2. **Network Segmentation**: Separate networks for different traffic types
3. **Resource Limits**: CPU and memory limits prevent resource exhaustion
4. **HTTPS Only**: All traffic encrypted via Let's Encrypt
5. **DNS-01 Challenge**: No need to expose HTTP for certificate validation

## Troubleshooting

### Check if Cloudflare token is loaded

```bash
# Inside the Caddy container
incus exec caddy01 -- cat /etc/caddy/cloudflare_token
# Should show the token (only works as root)

# Check Caddy logs for DNS issues
incus exec caddy01 -- caddy logs
```

### Verify Caddyfile syntax

```bash
# Validate Caddyfile
incus exec caddy01 -- caddy validate --config /etc/caddy/Caddyfile
```

### Test certificate acquisition

```bash
# Watch Caddy logs for ACME challenges
incus exec caddy01 -- caddy logs --follow
```

## Related Modules

- [grafana](../grafana/) - Generates Caddy config blocks for Grafana
- Future services will follow the same pattern

## References

- [Caddy Documentation](https://caddyserver.com/docs/)
- [Caddy Cloudflare Module](https://github.com/caddy-dns/cloudflare)
- [ACME DNS-01 Challenge](https://letsencrypt.org/docs/challenge-types/#dns-01-challenge)
- [Cloudflare API Tokens](https://developers.cloudflare.com/fundamentals/api/get-started/create-token/)
