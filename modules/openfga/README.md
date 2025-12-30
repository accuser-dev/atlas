# OpenFGA Terraform Module

This module deploys OpenFGA for fine-grained authorization (FGA) using relationship-based access control.

## Features

- **Relationship-Based Access**: Define authorization using relationship tuples
- **HTTP/gRPC APIs**: Both REST and gRPC interfaces
- **SQLite Storage**: Persistent storage for authorization data
- **Preshared Key Auth**: Secure API authentication
- **Prometheus Metrics**: Built-in observability

## Usage

```hcl
module "openfga01" {
  source = "../../modules/openfga"

  instance_name = "openfga01"
  profile_name  = "openfga"

  profiles = [
    module.base.container_base_profile.name,
    module.base.management_network_profile.name,
  ]

  # Authentication
  preshared_keys = [var.openfga_api_key]

  # Storage
  enable_data_persistence = true
  data_volume_name        = "openfga01-data"
}
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenFGA Container                         │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐  │
│   │                  OpenFGA Server                       │  │
│   │                                                       │  │
│   │   /var/lib/openfga/data.db  (SQLite database)        │  │
│   │                                                       │  │
│   │   :8080        ───► HTTP API                         │  │
│   │   :8081        ───► gRPC API                         │  │
│   │   :3002        ───► Prometheus metrics               │  │
│   └──────────────────────────────────────────────────────┘  │
│                              │                               │
│                              ▼                               │
│   ┌──────────────────────────────────────────────────────┐  │
│   │              Authorization Model                      │  │
│   │   • Type definitions (user, document, folder)        │  │
│   │   • Relations (owner, editor, viewer)                │  │
│   │   • Relationship tuples (user:anne is owner of doc:1)│  │
│   └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Configuration

### Creating an Authorization Model

After deployment, create a store and model:

```bash
# Create a store
curl -X POST http://openfga01.incus:8080/stores \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "my-app"}'

# Create an authorization model
curl -X POST http://openfga01.incus:8080/stores/$STORE_ID/authorization-models \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "schema_version": "1.1",
    "type_definitions": [
      {
        "type": "user"
      },
      {
        "type": "document",
        "relations": {
          "owner": { "this": {} },
          "editor": { "union": { "child": [{ "this": {} }, { "computedUserset": { "relation": "owner" }}]}},
          "viewer": { "union": { "child": [{ "this": {} }, { "computedUserset": { "relation": "editor" }}]}}
        },
        "metadata": {
          "relations": {
            "owner": { "directly_related_user_types": [{"type": "user"}] },
            "editor": { "directly_related_user_types": [{"type": "user"}] },
            "viewer": { "directly_related_user_types": [{"type": "user"}] }
          }
        }
      }
    ]
  }'
```

### Writing Relationship Tuples

```bash
curl -X POST http://openfga01.incus:8080/stores/$STORE_ID/write \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "writes": {
      "tuple_keys": [
        {"user": "user:anne", "relation": "owner", "object": "document:budget"}
      ]
    }
  }'
```

### Checking Authorization

```bash
curl -X POST http://openfga01.incus:8080/stores/$STORE_ID/check \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "tuple_key": {
      "user": "user:anne",
      "relation": "viewer",
      "object": "document:budget"
    }
  }'
# Returns {"allowed": true}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `instance_name` | Name of the OpenFGA instance | `string` | n/a | yes |
| `profile_name` | Name of the Incus profile | `string` | n/a | yes |
| `preshared_keys` | API authentication keys | `list(string)` | n/a | yes |
| `profiles` | List of Incus profiles | `list(string)` | `[]` | no |
| `image` | Container image | `string` | `"images:alpine/3.21/cloud"` | no |
| `openfga_version` | OpenFGA version | `string` | `"1.8.2"` | no |
| `cpu_limit` | CPU limit (1-64) | `string` | `"1"` | no |
| `memory_limit` | Memory limit | `string` | `"256MB"` | no |
| `storage_pool` | Storage pool | `string` | `"local"` | no |
| `root_disk_size` | Root disk size | `string` | `"1GB"` | no |
| `http_port` | HTTP API port | `string` | `"8080"` | no |
| `grpc_port` | gRPC API port | `string` | `"8081"` | no |
| `metrics_port` | Metrics port | `string` | `"3002"` | no |
| `playground_port` | Playground port (empty to disable) | `string` | `""` | no |
| `enable_data_persistence` | Enable persistent storage | `bool` | `true` | no |
| `data_volume_name` | Data volume name | `string` | `"openfga-data"` | no |
| `data_volume_size` | Data volume size | `string` | `"1GB"` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_name` | Name of the created instance |
| `http_endpoint` | HTTP API endpoint |
| `grpc_endpoint` | gRPC API endpoint |
| `metrics_endpoint` | Prometheus metrics endpoint |

## Troubleshooting

### Check OpenFGA status

```bash
incus exec openfga01 -- rc-service openfga status
```

### View logs

```bash
incus exec openfga01 -- cat /var/log/openfga/openfga.log
```

### Test API health

```bash
curl http://openfga01.incus:8080/healthz
```

### List stores

```bash
curl http://openfga01.incus:8080/stores \
  -H "Authorization: Bearer $API_KEY"
```

## Related Modules

- [dex](../dex/) - OIDC authentication (complements authorization)
- [grafana](../grafana/) - Integrate FGA with Grafana RBAC
- [base-infrastructure](../base-infrastructure/) - Provides base profiles

## References

- [OpenFGA Documentation](https://openfga.dev/docs)
- [OpenFGA Playground](https://play.fga.dev/)
- [Modeling Guide](https://openfga.dev/docs/modeling)
- [API Reference](https://openfga.dev/api/service)
