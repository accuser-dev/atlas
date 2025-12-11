# Atlantis Custom Image

This directory contains the Dockerfile for building a custom Atlantis image for GitOps Terraform/OpenTofu workflow.

## Base Image

- **Base**: `ghcr.io/runatlantis/atlantis:v0.35.0`
- **Official**: Yes, from [runatlantis/atlantis](https://github.com/runatlantis/atlantis)
- **Version**: Pinned to v0.35.0 for reproducibility and security (Dependabot tracks updates)
- **User**: Runs as `atlantis` user (non-root) at runtime

## Included Tools

The base image includes:
- **Terraform**: v1.13.4 (default)
- **OpenTofu**: v1.10.6
- **Conftest**: v0.63.0

## Building

```bash
# From the docker/atlantis directory
docker build -t atlas/atlantis:latest .

# Or from the project root using the Makefile
make build-atlantis
```

## Image Features

### GitOps Workflow

Atlantis provides pull request automation for Terraform/OpenTofu:

1. Developer opens PR with infrastructure changes
2. Atlantis automatically runs `plan` and comments results
3. Reviewer approves PR and comments `atlantis apply`
4. Atlantis applies changes and merges PR

### Security

**Non-root User**
- Runs as `atlantis` user at runtime (not root)
- Follows container security best practices

**Health Check**
- Built-in Docker/Incus health check using Atlantis's `/healthz` endpoint
- Interval: 30 seconds
- Timeout: 3 seconds
- Start period: 30 seconds
- Retries: 3 attempts before marking unhealthy

### Configuration

**Environment Variables**

| Variable | Description | Default |
|----------|-------------|---------|
| `ATLANTIS_PORT` | Port Atlantis listens on | `4141` |
| `ATLANTIS_DATA_DIR` | Data directory | `/home/atlantis` |
| `ATLANTIS_DEFAULT_TF_VERSION` | Default Terraform version | `1.13.4` |
| `ATLANTIS_GH_USER` | GitHub username | (required) |
| `ATLANTIS_GH_TOKEN` | GitHub personal access token | (required) |
| `ATLANTIS_GH_WEBHOOK_SECRET` | GitHub webhook secret | (required) |
| `ATLANTIS_REPO_ALLOWLIST` | Allowed repositories | (required) |
| `ATLANTIS_ATLANTIS_URL` | Atlantis URL for webhooks | (required) |

**Example Terraform configuration:**

```hcl
module "atlantis01" {
  source = "./modules/atlantis"

  environment_variables = {
    ATLANTIS_GH_USER          = "atlantis-bot"
    ATLANTIS_GH_TOKEN         = var.github_token
    ATLANTIS_GH_WEBHOOK_SECRET = var.webhook_secret
    ATLANTIS_REPO_ALLOWLIST   = "github.com/accuser-dev/*"
    ATLANTIS_ATLANTIS_URL     = "https://atlantis.example.com"
  }
}
```

## Customization Options

### 1. Custom repos.yaml

Create a `repos.yaml` for repository-specific configuration:

```yaml
repos:
  - id: github.com/accuser-dev/atlas
    apply_requirements: [approved, mergeable]
    allowed_overrides: [workflow]
    allow_custom_workflows: true
    workflow: opentofu
workflows:
  opentofu:
    plan:
      steps:
        - init:
            extra_args: ["-backend-config=backend.hcl"]
        - plan
    apply:
      steps:
        - apply
```

### 2. Server-side repo config

Uncomment the COPY line in Dockerfile:

```dockerfile
COPY --chown=atlantis:atlantis repos.yaml /home/atlantis/repos.yaml
```

Then pass `--repo-config=/home/atlantis/repos.yaml` to Atlantis.

## Usage in Terraform

Reference this image in your Terraform configuration:

```hcl
module "atlantis01" {
  source = "./modules/atlantis"

  image = "ghcr:accuser-dev/atlas/atlantis:latest"
  # ... other configuration
}
```

## Production Deployment

Images are automatically built and published to `ghcr.io/accuser-dev/atlas/atlantis:latest` by GitHub Actions when code is pushed to the `main` branch.

For local development:
```bash
# Build locally
make build-atlantis

# Test with OpenTofu
cd terraform
tofu plan
```

## Webhook Setup

Atlantis requires a GitHub webhook to receive PR events:

1. Go to repository Settings > Webhooks > Add webhook
2. Payload URL: `https://atlantis.example.com/events`
3. Content type: `application/json`
4. Secret: Same as `ATLANTIS_GH_WEBHOOK_SECRET`
5. Events: Pull requests, Pull request reviews, Issue comments, Pushes

## Health Monitoring

```bash
# Check Atlantis health directly
curl http://localhost:4141/healthz

# Or via Incus
incus exec atlantis01 -- wget -qO- http://localhost:4141/healthz
```

Expected response when healthy:
```
application/json
```

## References

- [Atlantis Documentation](https://www.runatlantis.io/docs/)
- [Atlantis GitHub](https://github.com/runatlantis/atlantis)
- [Docker Image](https://hub.docker.com/r/runatlantis/atlantis/)
