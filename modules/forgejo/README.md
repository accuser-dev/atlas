# Forgejo Terraform Module

This module deploys Forgejo (Git forge) as a system container on Incus with PostgreSQL or SQLite backend.

## Features

- **Debian Trixie** system container with Forgejo binary
- **PostgreSQL or SQLite** database backend support
- **SSH access** for git clone/push operations
- **Prometheus metrics** built-in support
- **Data persistence** with separate storage volume and snapshots
- **Admin user provisioning** during initial deployment

## Usage

### With PostgreSQL (Recommended)

```hcl
module "postgresql01" {
  source = "../../modules/postgresql"

  instance_name  = "postgresql01"
  profiles       = local.management_profiles
  admin_password = var.postgresql_admin_password

  databases = [{ name = "forgejo", owner = "forgejo" }]
  users     = [{ name = "forgejo", password = var.forgejo_db_password }]
}

module "forgejo01" {
  source = "../../modules/forgejo"

  instance_name = "forgejo01"
  profile_name  = "forgejo"
  profiles      = local.management_profiles
  target_node   = "node01"

  forgejo_version = "10.0.0"
  domain          = "git.example.com"

  admin_username = "admin"
  admin_password = var.forgejo_admin_password
  admin_email    = "admin@example.com"

  # PostgreSQL connection
  database_type     = "postgres"
  database_host     = module.postgresql01.ipv4_address
  database_port     = "5432"
  database_name     = "forgejo"
  database_user     = "forgejo"
  database_password = var.forgejo_db_password

  enable_data_persistence = true
  enable_ssh_access       = true
  enable_metrics          = true

  cpu_limit    = "2"
  memory_limit = "1GB"

  depends_on = [module.postgresql01]
}
```

### With SQLite (Simple Setup)

```hcl
module "forgejo01" {
  source = "../../modules/forgejo"

  instance_name = "forgejo01"
  profiles      = local.management_profiles

  database_type = "sqlite3"

  admin_username = "admin"
  admin_password = var.forgejo_admin_password
  admin_email    = "admin@example.com"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Container instance name | `string` | `"forgejo01"` | no |
| `profile_name` | Incus profile name | `string` | `"forgejo"` | no |
| `profiles` | Base profiles to apply | `list(string)` | `[]` | no |
| `target_node` | Cluster node for placement | `string` | `null` | no |
| `forgejo_version` | Forgejo version | `string` | `"10.0.0"` | no |
| `domain` | Domain name | `string` | `"localhost"` | no |
| `admin_username` | Admin username | `string` | `"admin"` | no |
| `admin_password` | Admin password | `string` | n/a | **yes** |
| `admin_email` | Admin email | `string` | n/a | **yes** |
| `database_type` | `postgres` or `sqlite3` | `string` | `"postgres"` | no |
| `database_host` | PostgreSQL host | `string` | `""` | when postgres |
| `database_password` | Database password | `string` | `""` | when postgres |
| `http_port` | Web UI port | `string` | `"3000"` | no |
| `ssh_port` | SSH port | `string` | `"22"` | no |
| `enable_ssh_access` | Enable SSH for git | `bool` | `true` | no |
| `enable_metrics` | Enable Prometheus metrics | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Container name |
| `ipv4_address` | Container IP address |
| `http_endpoint` | Web UI URL |
| `ssh_endpoint` | SSH clone URL |
| `ssh_clone_url` | git@host format for cloning |
| `metrics_endpoint` | Prometheus metrics URL |

## Git Operations

### Clone a repository (via SSH)

```bash
git clone git@forgejo01.incus:owner/repo.git
```

### Clone a repository (via HTTP)

```bash
git clone http://forgejo01.incus:3000/owner/repo.git
```

## Prometheus Integration

When `enable_metrics = true`, add this scrape config:

```yaml
- job_name: 'forgejo'
  static_configs:
    - targets: ['forgejo01.incus:3000']
      labels:
        service: 'forgejo'
        instance: 'forgejo01'
  metrics_path: '/metrics'
```

If `metrics_token` is set, add authorization:

```yaml
  authorization:
    type: Bearer
    credentials: 'your-metrics-token'
```

## Data Persistence

All Forgejo data is stored in `/var/lib/forgejo`:
- `repositories/` - Git repositories
- `data/` - LFS objects, attachments, avatars
- `log/` - Application logs
- `custom/` - Custom templates and assets

Enable automatic snapshots:

```hcl
enable_snapshots  = true
snapshot_schedule = "@daily"
snapshot_expiry   = "7d"
```

## SSH Access

By default, SSH is available on the container's internal IP:

```bash
# From within the network
ssh git@forgejo01.incus -p 22
```

For external SSH access (bridge mode), set:

```hcl
enable_external_ssh = true
external_ssh_port   = "2222"
```

For OVN environments, configure an OVN load balancer separately.
