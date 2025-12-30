# Atlantis Terraform Module

This module deploys Atlantis for GitOps-based Terraform workflow automation via GitHub pull requests.

## Features

- **GitOps Workflow**: Automatic `terraform plan` on PRs
- **GitHub Integration**: Webhook-based PR comments and status checks
- **Persistent Storage**: Plans cache and locks survive restarts
- **Server-side Config**: Optional repos.yaml injection
- **Automatic Snapshots**: Configurable backup scheduling

## Usage

```hcl
module "atlantis01" {
  source = "../../modules/atlantis"

  instance_name = "atlantis01"
  profile_name  = "atlantis"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # GitHub configuration
  github_user           = "my-bot-user"
  github_token          = var.github_token
  github_webhook_secret = var.github_webhook_secret
  repo_allowlist        = ["github.com/myorg/infrastructure"]

  # Atlantis URL (for webhook callbacks)
  atlantis_url = "https://atlantis.example.com"
  domain       = "atlantis.example.com"

  # Storage
  enable_data_persistence = true
  data_volume_name        = "atlantis01-data"
  data_volume_size        = "10GB"
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Atlantis Container                         │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                 Atlantis Server                       │  │
│   │                                                       │  │
│   │   /atlantis-data/       (plans, locks, repos)        │  │
│   │   /etc/atlantis/        (repos.yaml if enabled)      │  │
│   │                                                       │  │
│   │   :4141/events  ───► GitHub webhook endpoint         │  │
│   │   :4141/        ───► Web UI                          │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              GitHub Integration                       │  │
│   │   • Receive PR webhooks                              │  │
│   │   • Post plan output as PR comments                  │  │
│   │   • Apply changes on "atlantis apply" comment        │  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Server-side Repo Configuration

Enable server-side repos.yaml for advanced workflow customization:

```hcl
module "atlantis01" {
  # ...
  enable_repo_config = true
  repo_config = <<-EOT
    repos:
      - id: github.com/myorg/infrastructure
        apply_requirements: [approved, mergeable]
        workflow: custom
    workflows:
      custom:
        plan:
          steps:
            - init
            - plan
        apply:
          steps:
            - apply
  EOT
}
```

### Snapshot Scheduling

Enable automatic backups of the data volume:

```hcl
module "atlantis01" {
  # ...
  enable_snapshots  = true
  snapshot_schedule = "@daily"
  snapshot_expiry   = "7d"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the Atlantis instance | `string` | `"atlantis01"` | no |
| `profile_name` | Name of the Incus profile | `string` | `"atlantis"` | no |
| `profiles` | List of Incus profiles | `list(string)` | `["default"]` | no |
| `image` | Container image | `string` | `"ghcr:accuser-dev/atlas/atlantis:latest"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"2"` | no |
| `memory_limit` | Memory limit | `string` | `"1GB"` | no |
| `storage_pool` | Storage pool | `string` | `"local"` | no |
| `root_disk_size` | Root disk size | `string` | `"2GB"` | no |
| `github_user` | GitHub username or app ID | `string` | n/a | yes |
| `github_token` | GitHub token (sensitive) | `string` | n/a | yes |
| `github_webhook_secret` | Webhook secret (sensitive) | `string` | n/a | yes |
| `repo_allowlist` | Allowed repositories | `list(string)` | n/a | yes |
| `atlantis_url` | External URL for webhooks | `string` | n/a | yes |
| `domain` | Domain name | `string` | n/a | yes |
| `atlantis_port` | Listen port | `string` | `"4141"` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `true` | no |
| `data_volume_name` | Data volume name | `string` | `"atlantis01-data"` | no |
| `data_volume_size` | Data volume size | `string` | `"10GB"` | no |
| `enable_repo_config` | Enable repos.yaml | `bool` | `false` | no |
| `repo_config` | repos.yaml content | `string` | `""` | no |
| `enable_snapshots` | Enable automatic snapshots | `bool` | `false` | no |
| `snapshot_schedule` | Snapshot schedule | `string` | `"@daily"` | no |
| `snapshot_expiry` | Snapshot retention | `string` | `"7d"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `webhook_url` | GitHub webhook URL |
| `endpoint` | Atlantis web UI endpoint |

## Troubleshooting

### Check Atlantis logs

```bash
incus exec atlantis01 -- cat /var/log/atlantis.log
```

### Verify webhook connectivity

```bash
# From GitHub, check webhook delivery history
# Settings → Webhooks → Recent Deliveries
```

### Test GitHub token

```bash
incus exec atlantis01 -- wget -qO- \
  --header "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/user
```

## Related Modules

- [cloudflared](../cloudflared/) - Expose Atlantis via Cloudflare Tunnel
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [Atlantis Documentation](https://www.runatlantis.io/docs/)
- [Server Side Repo Config](https://www.runatlantis.io/docs/server-side-repo-config.html)
- [GitHub Webhook Setup](https://www.runatlantis.io/docs/configuring-webhooks.html#github)
