# Prefect Server Terraform Module

This module deploys Prefect server as a system container on Incus with PostgreSQL backend.

## Features

- **Debian Trixie** system container with Ansible-managed configuration
- **PostgreSQL** database backend (required)
- **Data persistence** with separate storage volume and snapshots
- **Web UI and API** on configurable port (default 4200)

## Usage

### With Shared PostgreSQL

```hcl
module "postgresql01" {
  source = "../../modules/postgresql"

  instance_name  = "postgresql01"
  profiles       = local.production_profiles
  admin_password = var.postgresql_admin_password

  databases = [{ name = "prefect", owner = "prefect" }]
  users     = [{ name = "prefect", password = var.prefect_db_password }]
}

module "prefect01" {
  source = "../../modules/prefect"

  instance_name = "prefect01"
  profile_name  = "prefect"
  profiles      = local.production_profiles
  target_node   = "node01"

  prefect_port      = "4200"
  database_host     = module.postgresql01.ipv4_address
  database_port     = "5432"
  database_name     = "prefect"
  database_user     = "prefect"
  database_password = var.prefect_db_password

  enable_data_persistence = true
  data_volume_name        = "prefect01-data"
  data_volume_size        = "5GB"

  cpu_limit    = "2"
  memory_limit = "1GB"

  depends_on = [module.postgresql01]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Container instance name | `string` | `"prefect01"` | no |
| `profile_name` | Incus profile name | `string` | `"prefect"` | no |
| `profiles` | Base profiles to apply | `list(string)` | `[]` | no |
| `target_node` | Cluster node for placement | `string` | `null` | no |
| `prefect_port` | Server UI/API port | `string` | `"4200"` | no |
| `database_host` | PostgreSQL host | `string` | n/a | **yes** |
| `database_password` | Database password | `string` | n/a | **yes** |
| `database_port` | PostgreSQL port | `string` | `"5432"` | no |
| `database_name` | Database name | `string` | `"prefect"` | no |
| `database_user` | Database username | `string` | `"prefect"` | no |
| `cpu_limit` | CPU limit | `string` | `"2"` | no |
| `memory_limit` | Memory limit | `string` | `"1GB"` | no |
| `enable_data_persistence` | Enable persistent volume | `bool` | `true` | no |
| `data_volume_size` | Data volume size | `string` | `"5GB"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Container name |
| `ipv4_address` | Container IP address |
| `prefect_endpoint` | Web UI/API URL |
| `prefect_api_url` | API URL for worker configuration |
| `storage_volume_name` | Data volume name (if enabled) |

## Data Persistence

Prefect data is stored in `/var/lib/prefect`. Enable automatic snapshots:

```hcl
enable_snapshots  = true
snapshot_schedule = "@daily"
snapshot_expiry   = "7d"
```

## Post-Deployment

After Terraform creates the container, use Ansible to install and configure Prefect server:

1. Install Prefect: `pip install prefect`
2. Configure database connection string
3. Start Prefect server: `prefect server start --host 0.0.0.0`

Workers connect using the API URL:
```bash
PREFECT_API_URL=http://prefect01.incus:4200/api prefect worker start
```
