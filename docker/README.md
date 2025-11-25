# Custom Docker Images for Atlas

This directory contains custom Docker images for the Atlas monitoring stack.

## Overview

The Atlas project uses custom Docker images that are:
- **Built automatically** by GitHub Actions when code is pushed to the main branch
- **Published to GitHub Container Registry** (ghcr.io)
- **Publicly accessible** without authentication
- **Extended from official images** with custom plugins and configuration

## Image Registry

All production images are published to GitHub Container Registry:

- **Caddy**: `ghcr.io/accuser/atlas/caddy:latest`
- **Grafana**: `ghcr.io/accuser/atlas/grafana:latest`
- **Loki**: `ghcr.io/accuser/atlas/loki:latest`
- **Prometheus**: `ghcr.io/accuser/atlas/prometheus:latest`
- **step-ca**: `ghcr.io/accuser/atlas/step-ca:latest`

These images are used by default in all OpenTofu modules.

## Local Development

### Building Images Locally

For testing and development, you can build images locally:

```bash
# Build all images
make build-all

# Or build individually
make build-caddy
make build-grafana
make build-loki
make build-prometheus
make build-step-ca
```

### Viewing Built Images

```bash
# List Atlas Docker images
make list-images

# Or directly
docker images | grep atlas
```

**Note:** Local builds are tagged as `atlas/<service>:latest` and are for testing only. Production deployments use images from ghcr.io.

## CI/CD Workflow

### Automatic Builds

When you push code to GitHub:

1. **GitHub Actions triggers** on push to `main` branch
2. **Docker images are built** in parallel (all five services)
3. **Images are published** to ghcr.io with appropriate tags
4. **Images are cached** for faster subsequent builds

### Image Tags

Published images receive multiple tags:

- `latest` - Latest build from main branch
- `<sha>` - Commit-specific tags for traceability

### Making Images Public

After the first push, images default to private. To make them public:

1. Visit: `https://github.com/accuser/atlas/packages`
2. Click on each package (caddy, grafana, loki, prometheus, step-ca)
3. Go to "Package settings"
4. Scroll to "Danger Zone"
5. Click "Change visibility" → "Public"

## Using Custom Images in OpenTofu

### Default Configuration

All OpenTofu modules default to ghcr.io images:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # Default image (no override needed)
  # image = "ghcr:accuser/atlas/grafana:latest"

  # ... other configuration
}
```

### Using Specific Tags

Override the image to use a specific tag:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # Use specific commit
  image = "ghcr:accuser/atlas/grafana:abc1234"

  # ... other configuration
}
```

### Using Official Images

To use official upstream images instead:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # Use official Docker Hub image
  image = "docker:grafana/grafana:latest"

  # ... other configuration
}
```

## Customizing Images

### Development Workflow

1. **Edit Dockerfile** in `docker/<service>/Dockerfile`
2. **Test locally**:
   ```bash
   make build-<service>
   docker run atlas/<service>:latest
   ```
3. **Commit and push** to trigger CI/CD
4. **Wait for build** to complete on GitHub Actions
5. **Deploy updated image**:
   ```bash
   make terraform-apply
   ```

### Example: Adding Grafana Plugin

```dockerfile
# docker/grafana/Dockerfile
FROM grafana/grafana:latest

# Install custom plugin
RUN grafana-cli plugins install grafana-piechart-panel

# Add custom configuration
COPY grafana.ini /etc/grafana/grafana.ini
```

After pushing to GitHub:
- GitHub Actions builds the image
- Published to ghcr.io
- Next `tofu apply` pulls the updated image

## Image Management

### Updating Images

Images are automatically rebuilt when:
- Code is pushed to main (directly or via PR merge)
- Dockerfiles are modified
- Base images are updated (manual rebuild needed)

To force a rebuild without code changes:
- Make a trivial change to the Dockerfile (e.g., add a comment)
- Or trigger workflow manually in GitHub Actions

### Forcing OpenTofu to Pull New Images

After publishing updated images:

```bash
# Option 1: Recreate specific container
cd terraform
tofu apply -replace='module.grafana01.incus_instance.grafana'

# Option 2: Restart container
incus restart grafana01

# Option 3: Rebuild container with new image
incus rebuild grafana01 ghcr:accuser/atlas/grafana:latest
```

## How It Works

### GitHub Container Registry Integration

When Terraform creates a container:

1. **Terraform requests** image from Incus
2. **Incus uses oci protocol** to pull from ghcr.io
3. **Image is pulled** (or cached if already present)
4. **Container is created** from the image

### Image Storage

- **Production images**: Stored in ghcr.io
- **Local images**: Stored in Docker daemon (`/var/lib/docker/`)
- **Incus cache**: Pulled images cached by Incus

### Authentication

Since images are public:
- No authentication required
- Incus can pull directly from ghcr.io
- No credentials needed in Terraform

## Troubleshooting

### Image Not Found During Terraform Apply

```
Error: Failed to create instance: Image not found
```

**Solutions:**

1. **Verify image exists** on ghcr.io:
   ```bash
   # Check package page
   open https://github.com/accuser/atlas/packages
   ```

2. **Verify image is public**:
   - Click on package
   - Check visibility (should show "Public")

3. **Test pull manually**:
   ```bash
   incus launch ghcr:accuser/atlas/grafana:latest test
   ```

4. **Check image name** in Terraform module:
   ```bash
   grep "default.*image" terraform/modules/grafana/variables.tf
   ```

### Container Uses Old Image Version

If container doesn't reflect recent image changes:

```bash
# Force OpenTofu to recreate container
cd terraform
tofu apply -replace='module.grafana01.incus_instance.grafana'

# Or restart to pick up new image
incus restart grafana01
```

### GitHub Actions Build Failed

Check the workflow:

1. Visit: `https://github.com/accuser/atlas/actions`
2. Click on the failed workflow run
3. Review Docker build logs
4. Fix issues in Dockerfile
5. Push fix to trigger rebuild

### Disk Space Issues

Clean up old Docker images locally:

```bash
# Remove unused images
docker image prune -a

# Check disk usage
docker system df

# Clean everything (careful!)
docker system prune -a
```

## Best Practices

1. **Test locally first** - Build and test images locally before pushing
2. **Use semantic versioning** - Tag releases with version numbers when ready
3. **Document changes** - Update service README when changing Dockerfiles
4. **Keep images small** - Use multi-stage builds when possible
5. **Cache layers** - Order Dockerfile commands to maximize cache hits
6. **Public images only** - Keep images public for easy Incus access

## Example Workflow

### Modifying Grafana Image

```bash
# 1. Create feature branch
git checkout -b add-grafana-plugin

# 2. Modify Dockerfile
vim docker/grafana/Dockerfile
# Add: RUN grafana-cli plugins install grafana-piechart-panel

# 3. Test locally (optional)
make build-grafana
docker run -p 3000:3000 atlas/grafana:latest

# 4. Commit and push
git add docker/grafana/Dockerfile
git commit -m "Add piechart plugin to Grafana"
git push origin add-grafana-plugin

# 5. Create PR, merge to main

# 6. Wait for GitHub Actions to build and publish

# 7. Deploy updated image
make terraform-apply

# 8. Verify
incus exec grafana01 -- grafana-cli plugins list
```

## Alternative: Docker Hub

If you prefer Docker Hub over ghcr.io:

1. **Update GitHub Actions workflow** (`.github/workflows/terraform-ci.yml`):
   ```yaml
   - name: Log in to Docker Hub
     uses: docker/login-action@v3
     with:
       username: ${{ secrets.DOCKERHUB_USERNAME }}
       password: ${{ secrets.DOCKERHUB_TOKEN }}
   ```

2. **Update image metadata**:
   ```yaml
   images: docker.io/yourusername/${{ matrix.service }}
   ```

3. **Update OpenTofu modules** to use Docker Hub images

## See Also

- [GitHub Actions Workflow](../.github/workflows/terraform-ci.yml) - CI/CD configuration
- [Makefile](../Makefile) - Build automation
- [CLAUDE.md](../CLAUDE.md) - Project architecture and documentation
- Individual service READMEs:
  - [caddy/README.md](caddy/README.md) - Caddy reverse proxy customization
  - [grafana/README.md](grafana/README.md) - Grafana plugins and provisioning
  - [loki/README.md](loki/README.md) - Loki configuration
  - [prometheus/README.md](prometheus/README.md) - Prometheus rules and configuration
  - [step-ca/README.md](step-ca/README.md) - step-ca internal PKI configuration
