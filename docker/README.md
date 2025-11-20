# Custom Docker Images for Atlas

This directory contains custom Docker images for the Atlas monitoring stack.

## Overview

The Atlas project uses custom Docker images that are built locally and accessed directly by Incus via the `docker:` protocol. This approach allows you to:
- Pre-install plugins and packages
- Bake in configuration defaults
- Create reproducible, versioned deployments
- Avoid runtime configuration complexity

## Building Images

### Quick Start

```bash
# Build all images
make build-all

# Or build individually
make build-caddy
make build-grafana
make build-loki
make build-prometheus
```

### What Happens During Build

1. **Build** - Docker image is built using the Dockerfile
2. **Tag** - Image is tagged (default: `atlas/<service>:latest`)
3. **Available** - Image is immediately available to Incus via Docker daemon

### Viewing Built Images

```bash
# List Atlas Docker images
make list-images

# Or directly
docker images | grep atlas
```

## Using Custom Images in Terraform

### Using Docker Protocol (Recommended)

After building images with `make build-all`, reference them in Terraform using the `docker:` protocol:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # Use custom image from local Docker daemon
  image = "docker:atlas/grafana:latest"

  # ... other configuration
}
```

**How it works:**
- When you use `docker:` protocol, Incus accesses images from your local Docker daemon directly
- **No import step is needed** - images are available immediately after building
- Incus will pull the image from Docker when creating the container

### Using Official Images

You can continue using official images from Docker Hub:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # Use official Docker Hub image (default in modules)
  image = "docker:grafana/grafana"

  # ... other configuration
}
```

## Image Management

### Updating Images

When you modify a Dockerfile and want to update:

```bash
# Rebuild specific image
make build-grafana

# Or rebuild all
make build-all
```

**Important:** After rebuilding, Incus needs to recreate containers to use the new image:

```bash
cd terraform
terraform apply -replace='incus_instance.grafana01'
```

Or restart the container to pick up the new image:
```bash
incus restart grafana01
```

### Image Versioning

You can tag images with versions:

```bash
# Build with specific tag
IMAGE_TAG=v1.0.0 make build-all

# This creates: atlas/grafana:v1.0.0, etc.
```

Then reference in Terraform:

```hcl
module "grafana01" {
  image = "docker:atlas/grafana:v1.0.0"
  # ...
}
```

## How It Works

### The Docker Protocol

When you use `docker:` protocol in Incus:

```bash
# Example: Using custom Grafana image in Terraform

# 1. Build Docker image
make build-grafana
# Creates: atlas/grafana:latest in Docker

# 2. Reference in Terraform
# image = "docker:atlas/grafana:latest"

# 3. Terraform apply
# Incus pulls image directly from Docker daemon
```

### Behind the Scenes

When Incus creates a container with `docker:` protocol:
1. Incus checks if the image exists in Docker daemon
2. If found, Incus pulls the image layers directly
3. Container is created using the Docker image
4. No separate import or conversion needed

### Image Storage

Images are stored in the Docker daemon:
- Location: Docker's image storage (typically `/var/lib/docker/`)
- Managed by Docker, not Incus
- Use `docker images` to view available images

## Troubleshooting

### Image Not Found During Terraform Apply

```
Error: Failed to create instance: Image not found
```

**Solution:**
```bash
# Verify the image exists in Docker
docker images | grep atlas

# If missing, build it
make build-grafana

# Check the exact image name
docker images atlas/grafana

# Ensure Terraform uses correct reference
# image = "docker:atlas/grafana:latest"
```

### Container Uses Old Image Version

If you've rebuilt an image but the container still uses the old version:

```bash
# Option 1: Recreate via Terraform
cd terraform
terraform apply -replace='incus_instance.grafana01'

# Option 2: Restart container
incus restart grafana01

# Option 3: Rebuild container
incus rebuild grafana01 docker:atlas/grafana:latest
```

### Disk Space Issues

Docker images can be large. Clean up periodically:

```bash
# Remove unused Docker images
docker image prune -a

# Remove dangling images
docker image prune

# Check disk usage
docker system df
```

## Best Practices

1. **Use Makefile targets** - `make build-all` handles everything correctly
2. **Build before deploying** - Run `make build-all` before `terraform apply`
3. **Use docker: protocol** - Always prefix with `docker:` in Terraform: `image = "docker:atlas/grafana:latest"`
4. **Version your images** - Tag with versions for rollback capability
5. **Test locally first** - Test image builds before using in production
6. **Document changes** - Update service README when changing Dockerfiles

## Example Workflow

```bash
# 1. Modify Dockerfile
vim docker/grafana/Dockerfile

# 2. Build image
make build-grafana

# 3. Update Terraform to use custom image
# Edit terraform/main.tf:
#   image = "docker:atlas/grafana:latest"

# 4. Apply changes
cd terraform
terraform plan
terraform apply

# 5. Verify
incus list
incus exec grafana01 -- grafana-cli plugins list
```

## Alternative: Docker Registry

For production or team environments, consider using a Docker registry:

```bash
# Option 1: Use Docker Hub
docker tag atlas/grafana:latest yourusername/atlas-grafana:latest
docker push yourusername/atlas-grafana:latest

# Use in Terraform
# image = "docker:yourusername/atlas-grafana:latest"

# Option 2: Local registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2
docker tag atlas/grafana:latest localhost:5000/atlas/grafana:latest
docker push localhost:5000/atlas/grafana:latest

# Use in Terraform
# image = "docker:localhost:5000/atlas/grafana:latest"
```

**Benefits:**
- ✅ Works well with CI/CD
- ✅ Supports multiple team members
- ✅ Versioning built-in
- ✅ Remote access for Incus hosts

**Considerations:**
- ❌ Requires registry infrastructure (for local registry)
- ❌ More complex than local Docker daemon

## See Also

- [Makefile](../Makefile) - Build automation
- [CLAUDE.md](../CLAUDE.md) - Project architecture and documentation
- Individual service READMEs:
  - [caddy/README.md](caddy/README.md) - Caddy reverse proxy customization
  - [grafana/README.md](grafana/README.md) - Grafana plugins and provisioning
  - [loki/README.md](loki/README.md) - Loki configuration
  - [prometheus/README.md](prometheus/README.md) - Prometheus rules and configuration
