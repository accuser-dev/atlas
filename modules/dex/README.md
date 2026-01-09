# Dex Terraform Module

This module deploys Dex as an OpenID Connect (OIDC) identity provider with GitHub authentication.

## Features

- **Debian Trixie**: Uses Debian Trixie system container with systemd
- **OIDC Provider**: Standards-compliant identity provider
- **GitHub Connector**: Authenticate users via GitHub OAuth
- **Static Clients**: Configure OAuth2 clients for services
- **SQLite Storage**: Persistent storage for tokens and sessions
- **Prometheus Metrics**: Built-in metrics endpoint
- **Systemd Integration**: Proper service management

## Usage

```hcl
module "dex01" {
  source = "../../modules/dex"

  instance_name = "dex01"
  profile_name  = "dex"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # Dex configuration
  issuer_url = "https://auth.example.com/dex"

  # GitHub connector
  github_client_id     = var.github_oauth_client_id
  github_client_secret = var.github_oauth_client_secret
  github_allowed_orgs  = ["myorg"]

  # Static clients
  static_clients = [
    {
      id            = "grafana"
      name          = "Grafana"
      secret        = var.grafana_oauth_secret
      redirect_uris = ["https://grafana.example.com/login/generic_oauth"]
    },
    {
      id            = "cli"
      name          = "CLI Tool"
      public        = true
      redirect_uris = ["http://localhost:8080/callback"]
    }
  ]

  # Storage
  enable_data_persistence = true
  data_volume_name        = "dex01-data"
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Dex Container                           │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                    Dex Server                         │  │
│   │                                                       │  │
│   │   /etc/dex/config.yaml     (main config)             │  │
│   │   /var/lib/dex/dex.db      (SQLite database)         │  │
│   │                                                       │  │
│   │   :5556/dex    ───► OIDC endpoints                   │  │
│   │   :5557        ───► gRPC API                         │  │
│   │   :5558        ───► Prometheus metrics               │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Authentication Flow                      │  │
│   │   1. User requests login                             │  │
│   │   2. Dex redirects to GitHub                         │  │
│   │   3. User authenticates with GitHub                  │  │
│   │   4. GitHub redirects back to Dex                    │  │
│   │   5. Dex issues OIDC tokens                          │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### GitHub OAuth Setup

1. Create a GitHub OAuth App:
   - Go to Settings → Developer Settings → OAuth Apps
   - Set callback URL: `https://auth.example.com/dex/callback`

2. Configure in Terraform:
```hcl
module "dex01" {
  # ...
  github_client_id     = "your-client-id"
  github_client_secret = "your-client-secret"
  github_allowed_orgs  = ["your-org"]  # Optional: restrict to org members
}
```

### Public Clients (CLI Tools)

For CLI tools that can't keep secrets:

```hcl
static_clients = [
  {
    id            = "my-cli"
    name          = "My CLI Tool"
    public        = true  # No secret required
    redirect_uris = ["http://localhost:8080/callback"]
  }
]
```

### Grafana Integration

Configure Grafana to use Dex for authentication:

```hcl
module "grafana01" {
  # ...
  environment_variables = {
    GF_AUTH_GENERIC_OAUTH_ENABLED       = "true"
    GF_AUTH_GENERIC_OAUTH_NAME          = "GitHub"
    GF_AUTH_GENERIC_OAUTH_CLIENT_ID     = "grafana"
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET = var.grafana_oauth_secret
    GF_AUTH_GENERIC_OAUTH_AUTH_URL      = "https://auth.example.com/dex/auth"
    GF_AUTH_GENERIC_OAUTH_TOKEN_URL     = "https://auth.example.com/dex/token"
    GF_AUTH_GENERIC_OAUTH_API_URL       = "https://auth.example.com/dex/userinfo"
    GF_AUTH_GENERIC_OAUTH_SCOPES        = "openid profile email groups"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Dex instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `issuer_url` | OIDC issuer URL (must include /dex) | `string` | n/a | yes |
| `github_client_id` | GitHub OAuth client ID | `string` | n/a | yes |
| `github_client_secret` | GitHub OAuth client secret | `string` | n/a | yes |
| `profiles` | List of Incus profiles | `list(string)` | `[]` | no |
| `image` | Container image | `string` | `"images:debian/trixie/cloud"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit | `string` | `"128MB"` | no |
| `storage_pool` | Storage pool | `string` | `"local"` | no |
| `root_disk_size` | Root disk size | `string` | `"1GB"` | no |
| `http_port` | HTTP port | `string` | `"5556"` | no |
| `grpc_port` | gRPC port | `string` | `"5557"` | no |
| `metrics_port` | Metrics port | `string` | `"5558"` | no |
| `github_allowed_orgs` | Allowed GitHub orgs | `list(string)` | `[]` | no |
| `static_clients` | OAuth2 clients | `list(object)` | `[]` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `true` | no |
| `data_volume_name` | Data volume name | `string` | `"dex-data"` | no |
| `data_volume_size` | Data volume size | `string` | `"1GB"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `issuer_url` | OIDC issuer URL |
| `http_endpoint` | HTTP endpoint |
| `metrics_endpoint` | Prometheus metrics endpoint |

## Troubleshooting

### Check Dex service status

```bash
incus exec dex01 -- systemctl status dex
```

### Check Dex logs

```bash
incus exec dex01 -- journalctl -u dex --no-pager -n 50
```

### Verify OIDC discovery

```bash
curl https://auth.example.com/dex/.well-known/openid-configuration | jq
```

### Test token endpoint

```bash
# Get a token (requires valid client credentials)
curl -X POST https://auth.example.com/dex/token \
  -d "grant_type=client_credentials&client_id=grafana&client_secret=secret"
```

## Related Modules

- [grafana](../grafana/) - Configure OAuth with Dex
- [openfga](../openfga/) - Fine-grained authorization
- [cloudflared](../cloudflared/) - Expose Dex via Cloudflare Tunnel

## References

- [Dex Documentation](https://dexidp.io/docs/)
- [GitHub Connector](https://dexidp.io/docs/connectors/github/)
- [OpenID Connect Spec](https://openid.net/connect/)
