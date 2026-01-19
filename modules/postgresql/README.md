# PostgreSQL Terraform Module

This module deploys PostgreSQL as a system container on Incus with optional Prometheus metrics.

## Features

- **Debian Trixie** system container with PostgreSQL
- **Database provisioning** - Create databases and users at deployment
- **Prometheus metrics** - Optional postgres_exporter integration
- **Data persistence** - Separate storage volume with snapshot support
- **Network access control** - Configurable allowed networks via pg_hba.conf

## Usage

```hcl
module "postgresql01" {
  source = "../../modules/postgresql"

  instance_name = "postgresql01"
  profile_name  = "postgresql"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  target_node = "node01"

  admin_password = var.postgresql_admin_password

  databases = [
    { name = "myapp", owner = "myapp_user" },
    { name = "analytics" }
  ]

  users = [
    { name = "myapp_user", password = var.myapp_db_password },
    { name = "readonly", password = var.readonly_password, options = ["NOSUPERUSER", "NOCREATEDB"] }
  ]

  enable_data_persistence = true
  data_volume_name        = "postgresql01-data"
  data_volume_size        = "50GB"

  enable_snapshots  = true
  snapshot_schedule = "@daily"
  snapshot_expiry   = "7d"

  enable_metrics = true

  cpu_limit    = "2"
  memory_limit = "2GB"
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Container instance name | `string` | `"postgresql01"` | no |
| `profile_name` | Incus profile name | `string` | `"postgresql"` | no |
| `profiles` | Base profiles to apply | `list(string)` | `[]` | no |
| `target_node` | Cluster node for placement | `string` | `null` | no |
| `admin_password` | PostgreSQL admin password | `string` | n/a | **yes** |
| `databases` | Databases to create | `list(object)` | `[]` | no |
| `users` | Users to create | `list(object)` | `[]` | no |
| `postgresql_port` | PostgreSQL listen port | `string` | `"5432"` | no |
| `allowed_networks` | CIDRs allowed to connect | `list(string)` | RFC1918 ranges | no |
| `enable_data_persistence` | Enable data volume | `bool` | `true` | no |
| `data_volume_size` | Data volume size | `string` | `"20GB"` | no |
| `enable_metrics` | Enable postgres_exporter | `bool` | `true` | no |
| `metrics_port` | Metrics port | `string` | `"9187"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Container name |
| `ipv4_address` | Container IP address |
| `postgresql_endpoint` | Connection string |
| `postgresql_internal_endpoint` | Connection string using Incus DNS |
| `metrics_endpoint` | Prometheus metrics URL |

## Database Object

```hcl
{
  name     = "mydb"        # Required: database name
  owner    = "myuser"      # Optional: owner user
  encoding = "UTF8"        # Optional: encoding (default: UTF8)
}
```

## User Object

```hcl
{
  name     = "myuser"              # Required: username
  password = "secret"              # Required: password
  options  = ["CREATEDB"]          # Optional: PostgreSQL role options
}
```

## Connecting to PostgreSQL

From another container on the same network:

```bash
psql -h postgresql01.incus -U myuser -d mydb
```

Connection string for applications:

```
postgresql://myuser:password@postgresql01.incus:5432/mydb
```

## Prometheus Integration

When `enable_metrics = true`, add this scrape config to Prometheus:

```yaml
- job_name: 'postgresql'
  static_configs:
    - targets: ['postgresql01.incus:9187']
      labels:
        service: 'postgresql'
        instance: 'postgresql01'
```

## Backup

The module supports automatic snapshots via Incus:

```hcl
enable_snapshots  = true
snapshot_schedule = "@daily"
snapshot_expiry   = "7d"
```

For point-in-time recovery, consider setting up pg_dump-based backups as well.
