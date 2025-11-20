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

1. **docker-build** - Validates Docker images can be built
   - Builds all four service images (Caddy, Grafana, Loki, Prometheus)
   - Uses Docker BuildKit with GitHub Actions cache
   - Does not push images (validation only)
   - Images are tagged as `atlas/<service>:ci`

2. **terraform-checks** - Validates Terraform configuration
   - Runs after docker-build job completes
   - Checks:
     - Format: `terraform fmt -check -recursive`
     - Initialization: `terraform init -backend=false`
     - Validation: `terraform validate`
     - Plan: `terraform plan` (dry run with test variables)
   - Comments results on pull requests
   - Fails if format or validation checks fail

**Working Directory:**
All Terraform commands run in the `terraform/` directory.

**Test Variables:**
The workflow creates a minimal `terraform.tfvars` file for plan testing with placeholder values.

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

## Workflow Best Practices

- **Path filters**: Only trigger when relevant files change
- **Working directories**: Explicitly set `working-directory` for clarity
- **Cache**: Use GitHub Actions cache for Docker builds
- **PR comments**: Automatically comment results on pull requests
- **Continue on error**: Use for non-critical checks that should be reported but not fail the build
- **Dependency order**: Use `needs:` to sequence jobs appropriately
