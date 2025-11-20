# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform infrastructure project that manages Incus containers for a complete monitoring stack including Caddy reverse proxy, Grafana, Prometheus, and Loki. The setup provisions containerized services with automatic HTTPS certificate management, persistent storage, and dynamic configuration generation.

## Common Commands

### Terraform Operations
```bash
# Initialize Terraform (required first time or after provider changes)
terraform init

# Validate configuration
terraform validate

# Plan changes (see what will be applied)
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Format Terraform files
terraform fmt -recursive

# Show current state
terraform show

# View outputs (endpoints, configurations)
terraform output
```

### Working with tfvars
The `terraform.tfvars` file contains sensitive variables and is gitignored. Required variables:
- `cloudflare_api_token`: Cloudflare API token for DNS management
- Network configuration variables (IPv4/IPv6 addresses for development, testing, production networks)

## Architecture

### Modular Structure

The project uses Terraform modules for scalability and reusability:

**Root Level:**
- [versions.tf](versions.tf) - Terraform and provider version constraints
- [providers.tf](providers.tf) - Provider configuration
- [variables.tf](variables.tf) - Root-level input variable definitions
- [main.tf](main.tf) - Module instantiations and orchestration
- [networks.tf](networks.tf) - Network definitions (development, testing, production)
- [outputs.tf](outputs.tf) - Output values (endpoints, configurations)
- [terraform.tfvars](terraform.tfvars) - Variable values (gitignored, contains secrets)

**Modules:**
- [modules/caddy/](modules/caddy/) - Reverse proxy with dynamic Caddyfile generation
  - [main.tf](modules/caddy/main.tf) - Profile, container, and Caddyfile templating
  - [variables.tf](modules/caddy/variables.tf) - Module input variables
  - [outputs.tf](modules/caddy/outputs.tf) - Module outputs
  - [templates/Caddyfile.tftpl](modules/caddy/templates/Caddyfile.tftpl) - Caddyfile template
  - [versions.tf](modules/caddy/versions.tf) - Provider requirements

- [modules/grafana/](modules/grafana/) - Grafana observability platform
  - [main.tf](modules/grafana/main.tf) - Profile, container, and storage volume
  - [variables.tf](modules/grafana/variables.tf) - Module input variables including domain config
  - [outputs.tf](modules/grafana/outputs.tf) - Module outputs including Caddy config block
  - [templates/caddyfile.tftpl](modules/grafana/templates/caddyfile.tftpl) - Caddy reverse proxy template
  - [versions.tf](modules/grafana/versions.tf) - Provider requirements

- [modules/loki/](modules/loki/) - Log aggregation system (internal only)
  - [main.tf](modules/loki/main.tf) - Profile, container, and storage volume
  - [variables.tf](modules/loki/variables.tf) - Module input variables
  - [outputs.tf](modules/loki/outputs.tf) - Module outputs including endpoint
  - [versions.tf](modules/loki/versions.tf) - Provider requirements

- [modules/prometheus/](modules/prometheus/) - Metrics collection and storage (internal only)
  - [main.tf](modules/prometheus/main.tf) - Profile, container, storage volume, and config file
  - [variables.tf](modules/prometheus/variables.tf) - Module input variables including prometheus.yml config
  - [outputs.tf](modules/prometheus/outputs.tf) - Module outputs including endpoint
  - [versions.tf](modules/prometheus/versions.tf) - Provider requirements

### Infrastructure Components

1. **Incus Provider** ([providers.tf](providers.tf), [versions.tf](versions.tf))
   - Uses the `lxc/incus` provider (v1.0.0+)
   - Manages LXC/Incus containers and storage volumes

2. **Network Configuration** ([networks.tf](networks.tf))
   - Three managed networks: development, testing, production
   - Each network has configurable IPv4 and IPv6 addresses
   - NAT enabled for external connectivity

3. **Caddy Module** ([modules/caddy/](modules/caddy/))
   - Reverse proxy with automatic HTTPS via Let's Encrypt
   - Dynamic Caddyfile generation from service module outputs
   - Cloudflare DNS-01 ACME challenge support
   - Dual network interfaces (production + management)
   - Accepts `service_blocks` list for dynamic configuration

4. **Caddy Instance** (instantiated in [main.tf](main.tf))
   - Instance name: `caddy01`
   - Image: `docker:caddybuilds/caddy-cloudflare`
   - Resource limits: 2 CPUs, 1GB memory (configurable)
   - Dual network interfaces:
     - `eth0`: Connected to "production" network
     - `eth1`: Connected to "incusbr0" bridge
   - Caddyfile dynamically generated from module outputs

5. **Grafana Module** ([modules/grafana/](modules/grafana/))
   - Visualization and dashboarding platform
   - Persistent storage for dashboards and configuration (10GB)
   - Environment variable support for configuration
   - Generates Caddy reverse proxy configuration block
   - Domain-based access with IP restrictions

6. **Grafana Instance** (instantiated in [main.tf](main.tf))
   - Instance name: `grafana01`
   - Image: `docker:grafana/grafana`
   - Domain: `grafana.accuser.dev` (publicly accessible via Caddy)
   - Resource limits: 2 CPUs, 1GB memory
   - Storage: 10GB persistent volume for `/var/lib/grafana`
   - Network: Connected to production network

7. **Loki Module** ([modules/loki/](modules/loki/))
   - Log aggregation system (internal only)
   - Persistent storage for log data (50GB)
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source

8. **Loki Instance** (instantiated in [main.tf](main.tf))
   - Instance name: `loki01`
   - Image: `docker:grafana/loki`
   - Internal endpoint: `http://loki01.incus:3100`
   - Resource limits: 2 CPUs, 2GB memory
   - Storage: 50GB persistent volume for `/loki`
   - Network: Connected to production network (internal only)

9. **Prometheus Module** ([modules/prometheus/](modules/prometheus/))
   - Metrics collection and time-series database (internal only)
   - Persistent storage for metrics data (100GB)
   - Optional prometheus.yml configuration file injection
   - No public-facing reverse proxy configuration
   - Internal endpoint for Grafana data source

10. **Prometheus Instance** (instantiated in [main.tf](main.tf))
    - Instance name: `prometheus01`
    - Image: `docker:prom/prometheus`
    - Internal endpoint: `http://prometheus01.incus:9090`
    - Resource limits: 2 CPUs, 2GB memory
    - Storage: 100GB persistent volume for `/prometheus`
    - Network: Connected to production network (internal only)

### Dynamic Caddyfile Generation

The project uses a template-based approach for generating Caddyfile configurations:

1. **Service modules** (like Grafana) declare their domain and generate a Caddy config block via `caddy_config_block` output
2. **Root main.tf** collects all service blocks and passes them to the Caddy module as a list
3. **Caddy module** uses its internal template to combine service blocks with global configuration
4. **Result**: Automatically generated, consistent reverse proxy configuration

**Adding a new public service:**
```hcl
# In main.tf, add the service's caddy_config_block to the list
module "caddy01" {
  service_blocks = [
    module.grafana01.caddy_config_block,
    module.newservice01.caddy_config_block,  # Add here
  ]
}
```

### Storage Architecture

Each service with persistent storage uses Incus storage volumes:
- Automatically created by the module when `enable_data_persistence = true`
- Configurable size and name
- Mounted to service-specific paths in containers
- Survives container restarts and updates

**Current storage volumes:**
- `grafana01-data` - 10GB - `/var/lib/grafana`
- `loki01-data` - 50GB - `/loki`
- `prometheus01-data` - 100GB - `/prometheus`

### Adding New Service Modules

**For public-facing services (with Caddy reverse proxy):**

1. Create module in `modules/yourservice/`
2. Add `domain`, `allowed_ip_range`, and port variables
3. Create `templates/caddyfile.tftpl` for reverse proxy config
4. Add `caddy_config_block` output using templatefile()
5. Instantiate module in root [main.tf](main.tf)
6. Add module's `caddy_config_block` to Caddy's `service_blocks` list

**For internal-only services (no public access):**

1. Create module in `modules/yourservice/`
2. Add storage and network configuration
3. Add endpoint output for internal connectivity
4. Instantiate module in root [main.tf](main.tf)
5. Connect from other services using `yourservice.incus:port`

**Example - Adding a new Grafana instance:**
```hcl
module "grafana02" {
  source = "./modules/grafana"

  instance_name = "grafana02"
  profile_name  = "grafana02"

  monitoring_network = incus_network.production.name

  domain           = "grafana-dev.accuser.dev"
  allowed_ip_range = "192.168.68.0/22"

  environment_variables = {
    GF_SECURITY_ADMIN_USER     = "admin"
    GF_SECURITY_ADMIN_PASSWORD = "secure-password"
  }

  enable_data_persistence = true
  data_volume_name        = "grafana02-data"
  data_volume_size        = "10GB"

  depends_on = [incus_network.production]
}

# Add to Caddy's service_blocks
module "caddy01" {
  service_blocks = [
    module.grafana01.caddy_config_block,
    module.grafana02.caddy_config_block,  # Add here
  ]
}
```

### Key Design Patterns

**Modular Architecture:**
- Each service type has its own module in `modules/`
- Modules are instantiated in the root [main.tf](main.tf)
- Easy to scale by adding new module instances
- Module parameters allow customization per instance

**Container Configuration Flow:**
1. Module defines profile with resource limits and network connectivity
2. Module creates storage volume (if persistence enabled)
3. Module creates container that references the profile
4. Module injects configuration files and environment variables
5. Root module orchestrates dependencies and network setup

**Dynamic Configuration:**
- Services declare their own reverse proxy configuration
- Caddy module assembles configurations into complete Caddyfile
- Type-safe: All values validated by Terraform
- DRY principle: No duplicate configuration

**Network Architecture:**
- Three environments: development, testing, production
- Services on same network can communicate via internal DNS
- Public services exposed via Caddy reverse proxy
- IP-based access control for security
- Automatic HTTPS via Let's Encrypt with Cloudflare DNS validation

**Storage Management:**
- Each service module manages its own storage volume
- Conditionally created based on `enable_data_persistence`
- Configurable size per instance
- Proper lifecycle management by Terraform

### Monitoring Stack Integration

The complete observability stack is designed to work together:

1. **Grafana** (public) - Visualization frontend
   - Access: `https://grafana.accuser.dev`
   - Connects to Prometheus and Loki as data sources

2. **Prometheus** (internal) - Metrics storage
   - Endpoint: `http://prometheus01.incus:9090`
   - Scrapes metrics from applications
   - Queried by Grafana for metric visualization

3. **Loki** (internal) - Log aggregation
   - Endpoint: `http://loki01.incus:3100`
   - Receives logs from applications
   - Queried by Grafana for log exploration

**Configuring Grafana data sources:**
```yaml
# Add in Grafana UI or via provisioning:
# Prometheus: http://prometheus01.incus:9090
# Loki: http://loki01.incus:3100
```

## Important Notes

- The `terraform.tfvars` file is gitignored and must be created manually with required secrets
- Caddy is built with Cloudflare DNS plugin (`caddybuilds/caddy-cloudflare` image)
- Access to services is restricted to the 192.168.68.0/22 subnet by default
- All services use the `production` network for connectivity
- Storage volumes are created automatically when modules are applied
- Each module has a `versions.tf` specifying the Incus provider requirement
- The cloud-init directory contains an alternative provisioning approach using xcaddy to build Caddy with plugins

## Outputs

After applying, use `terraform output` to view:
- `grafana_caddy_config` - Generated Caddy configuration for Grafana
- `loki_endpoint` - Internal Loki endpoint URL
- `prometheus_endpoint` - Internal Prometheus endpoint URL
