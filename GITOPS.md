# GitOps Workflow with Atlantis

This document describes the GitOps workflow for managing Atlas infrastructure using Atlantis.

## Overview

Atlantis provides PR-based infrastructure management:

```
Developer → GitHub PR → Webhook → Caddy → Atlantis → Plan/Apply → Infrastructure
```

**Key Features:**
- Automatic `terraform plan` on PR creation/update
- Plan output posted as PR comment
- `atlantis apply` via PR comment after approval
- PR-based change tracking and audit trail

## Architecture

### Network Isolation

Atlantis runs on a dedicated `gitops` network (10.60.0.0/24) isolated from other workloads:

| Network | CIDR | Purpose |
|---------|------|---------|
| gitops | 10.60.0.0/24 | Atlantis and CI/CD automation |

Caddy connects to the gitops network to proxy webhook requests to Atlantis.

### Security

**Webhook Protection:**
- IP allowlisting: Only GitHub webhook IPs can access Atlantis
- Rate limiting: 100 requests/minute per IP
- HTTPS only via Caddy reverse proxy
- Webhook secret validation

**GitHub IP Ranges:**
```
192.30.252.0/22
185.199.108.0/22
140.82.112.0/20
143.55.64.0/20
```

These IPs are configured in `var.atlantis_allowed_ip_range`.

## Enabling Atlantis

### Prerequisites

1. **GitHub Personal Access Token (PAT)**
   - Create a PAT with `repo` scope
   - For organization repos, also need `admin:org` scope for webhooks

2. **Webhook Secret**
   - Generate a random secret: `openssl rand -hex 32`
   - Used to validate webhook payloads

3. **Domain**
   - A domain pointing to your Caddy instance (e.g., `atlantis.example.com`)
   - DNS record must be configured before enabling

### Configuration

Add to `terraform.tfvars`:

```hcl
# Enable Atlantis
enable_atlantis = true

# Domain for webhook endpoint
atlantis_domain = "atlantis.example.com"

# GitHub credentials
atlantis_github_user   = "your-github-username"
atlantis_github_token  = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
atlantis_github_webhook_secret = "your-generated-secret"

# Repository allowlist
atlantis_repo_allowlist = ["github.com/your-org/your-repo"]
```

### Deployment

```bash
# Initial deployment creates Atlantis
make deploy

# Verify Atlantis is running
incus list atlantis01

# Check webhook endpoint is accessible
curl -I https://atlantis.example.com/healthz
```

### GitHub Webhook Setup

After deployment, configure the GitHub webhook:

1. Go to repository Settings > Webhooks > Add webhook
2. **Payload URL:** `https://atlantis.example.com/events`
3. **Content type:** `application/json`
4. **Secret:** Same as `atlantis_github_webhook_secret`
5. **Events:** Select individual events:
   - Pull requests
   - Pull request reviews
   - Issue comments
   - Pushes

## Workflow

### Making Infrastructure Changes

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/add-new-service
   ```

2. **Make Changes**
   - Edit Terraform files in `terraform/`
   - Commit and push

3. **Open Pull Request**
   - Atlantis automatically runs `terraform plan`
   - Plan output appears as PR comment

4. **Review Plan**
   - Review the plan output in PR comments
   - Discuss changes with team

5. **Apply Changes**
   - After PR approval, comment: `atlantis apply`
   - Atlantis runs `terraform apply`
   - Apply output appears as PR comment

6. **Merge PR**
   - After successful apply, merge the PR
   - Infrastructure changes are now live

### Atlantis Commands

Comment these on PRs to control Atlantis:

| Command | Description |
|---------|-------------|
| `atlantis plan` | Re-run plan |
| `atlantis plan -d terraform` | Plan specific directory |
| `atlantis apply` | Apply changes (after approval) |
| `atlantis unlock` | Unlock PR (if locked) |
| `atlantis help` | Show all commands |

## Configuration

### Repository Configuration

The `atlantis.yaml` file in the repository root defines:

```yaml
version: 3
projects:
  - name: atlas-infrastructure
    dir: terraform
    workspace: default
    autoplan:
      when_modified:
        - "*.tf"
        - "modules/**/*.tf"
      enabled: true
    apply_requirements:
      - mergeable
      - approved
    workflow: atlas
```

**Autoplan Triggers:**
- `*.tf` - Any Terraform file in terraform/
- `*.tftpl` - Template files
- `modules/**/*.tf` - Module files
- `prometheus-alerts.yml` - Alert rules

**Apply Requirements:**
- `mergeable` - PR must be mergeable (no conflicts)
- `approved` - PR must have at least one approval

### Custom Workflow

The `atlas` workflow uses backend configuration:

```yaml
workflows:
  atlas:
    plan:
      steps:
        - init:
            extra_args: ["-backend-config=backend.hcl"]
        - plan
    apply:
      steps:
        - apply
```

## Troubleshooting

### Atlantis Not Receiving Webhooks

1. **Check Caddy logs:**
   ```bash
   incus exec caddy01 -- tail -f /var/log/caddy/atlantis-access.log
   ```

2. **Check Atlantis logs:**
   ```bash
   incus exec atlantis01 -- docker logs atlantis
   ```

3. **Verify webhook delivery in GitHub:**
   - Repository Settings > Webhooks > Recent Deliveries
   - Check for failed deliveries and error messages

### Plan Fails

1. **Check backend configuration:**
   - Ensure `backend.hcl` exists and has valid credentials
   - Atlantis needs access to the S3-compatible backend

2. **Check permissions:**
   - GitHub token must have `repo` scope
   - Atlantis must be able to clone the repository

### Apply Fails

1. **Check apply requirements:**
   - PR must be approved
   - PR must be mergeable (no conflicts)

2. **Check Incus connectivity:**
   - Atlantis needs access to Incus API
   - Verify network connectivity to Incus host

## Resource Limits

| Resource | Value |
|----------|-------|
| CPU | 2 cores |
| Memory | 1GB |
| Storage | 10GB |

Storage is used for:
- Terraform plans cache
- Working directories
- Lock state

## References

- [Atlantis Documentation](https://www.runatlantis.io/docs/)
- [atlantis.yaml Reference](https://www.runatlantis.io/docs/repo-level-atlantis-yaml.html)
- [Custom Workflows](https://www.runatlantis.io/docs/custom-workflows.html)
- [Security Best Practices](https://www.runatlantis.io/docs/security.html)
