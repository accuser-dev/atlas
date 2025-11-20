# GitHub Actions Workflows

This directory contains CI/CD workflows for the Atlas infrastructure project.

## Workflows

### Terraform CI (`terraform-ci.yml`)

Validates Terraform configuration and builds Docker images on every push or pull request.

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Only when relevant files change:
  - `terraform/**.tf` - Terraform configuration files
  - `terraform/**.tftpl` - Terraform template files
  - `docker/**/Dockerfile` - Docker image definitions
  - `.github/workflows/terraform-ci.yml` - This workflow

**Jobs:**

Jobs run in this order to optimize cost and performance:

1. **terraform-validate** - Quick validation checks (runs first, ~30 seconds)
   - Format check: `terraform fmt -check -recursive`
   - Initialization: `terraform init -backend=false`
   - Validation: `terraform validate`
   - **Fails fast** if Terraform config is invalid
   - Prevents expensive Docker builds if Terraform has issues

2. **docker-build** - Validates Docker images (runs only after validation passes)
   - Uses **matrix strategy** to build all 4 images in parallel
   - Services: `[caddy, grafana, loki, prometheus]`
   - Each image builds independently with `fail-fast: false`
   - Uses Docker BuildKit with GitHub Actions cache (per-service scope)
   - On PRs: Builds and validates images (does not push)
   - On push to main/develop: Builds and pushes to GitHub Container Registry

**Job Dependencies:**
```
terraform-validate (fast, fails fast)
         ↓
docker-build (expensive, runs in parallel via matrix)
```

**Note:** `terraform plan` is not run in CI because:
- Requires actual Incus infrastructure (not available in GitHub Actions)
- Cannot connect to provider with test credentials
- Validation is already covered by `terraform validate`
- Developers should run `terraform plan` locally before creating PRs

**Performance Optimizations:**

1. **Fail fast validation** - Cheap Terraform checks run first
2. **Matrix builds** - Docker images build in parallel (4 concurrent jobs)
3. **Per-service cache** - Each Docker image has its own cache scope
4. **fail-fast: false** - One failed Docker build doesn't cancel others

**Working Directory:**
All Terraform commands run in the `terraform/` directory.

**Test Variables:**
The terraform-plan job creates a minimal `terraform.tfvars` file with placeholder values.

## Local Testing

You can test the workflow locally using [act](https://github.com/nektos/act):

```bash
# Install act (macOS)
brew install act

# Run the workflow
act push

# Run specific job
act -j docker-build
act -j terraform-checks
```

## Adding New Workflows

When adding new workflows:

1. Name the file descriptively: `<purpose>-ci.yml`
2. Add appropriate triggers and path filters
3. Use `working-directory` for commands in subdirectories
4. Document the workflow in this README
5. Test locally with `act` if possible

## GitHub Flow Integration

This workflow is designed to support GitHub Flow with `develop` as the main development branch:

**Feature Branch Workflow:**
1. Create branch from `develop`: `git checkout -b feature/issue-X-description`
2. Make changes and push: `git push -u origin feature/issue-X-description`
3. Open PR targeting `develop`
4. CI runs validation and builds (does not push images)
5. After approval and CI passes, merge to `develop`
6. CI rebuilds and pushes images with `develop` tag

**Release Workflow:**
1. When `develop` is stable, create PR from `develop` to `main`
2. CI validates the production-ready code
3. After approval, merge to `main`
4. CI rebuilds and pushes images with `latest` tag
5. Tag the release on `main`: `git tag -a v1.0.0 -m "Release 1.0.0"`

**Image Tagging Strategy:**
- `latest` - Production images from `main` branch
- `develop` - Development images from `develop` branch
- `<branch>-<sha>` - Branch-specific builds (on push to main/develop)

## Workflow Best Practices

- **Path filters**: Only trigger when relevant files change
- **Working directories**: Explicitly set `working-directory` for clarity
- **Cache**: Use GitHub Actions cache for Docker builds
- **PR comments**: Automatically comment results on pull requests
- **Continue on error**: Use for non-critical checks that should be reported but not fail the build
- **Dependency order**: Use `needs:` to sequence jobs appropriately

## Related Documentation

- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Full GitHub Flow workflow guide
- [CLAUDE.md](../../CLAUDE.md) - Project architecture and quick reference
