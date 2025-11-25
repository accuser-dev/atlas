# GitHub Actions Workflows

This directory contains CI/CD workflows for the Atlas infrastructure project.

## Overview

The CI/CD pipeline is split into two workflows for clarity and separation of concerns:

| Workflow | Purpose | Triggers |
|----------|---------|----------|
| `ci.yml` | Validation & Testing | Feature branches, PRs |
| `release.yml` | Build & Publish | Push to `main` |

## Workflows

### CI Workflow (`ci.yml`)

Validates code and tests Docker images on feature branches and pull requests.

**Triggers:**
- Push to `feature/**`, `fix/**`, `docs/**`, `refactor/**`, `test/**` branches
- Pull requests to `main` branch
- Only when relevant files change (terraform, docker, workflows)

**Jobs:**

```
┌─────────────────┐
│ tofu-validate   │ ← OpenTofu format, init, validate
└────────┬────────┘
         │
┌────────▼────────┐
│ detect-changes  │ ← Determine which images changed
└────────┬────────┘
         │
┌────────▼────────┐
│ docker-build    │ ← Build images (matrix: changed services)
└────────┬────────┘
         │
┌────────▼────────┐
│ docker-test     │ ← Run smoke tests (matrix: changed services)
└────────┬────────┘
         │
┌────────▼────────┐
│ ci-summary      │ ← Report final status
└─────────────────┘
```

**Behavior:**
- **Feature branches**: Selective builds (only changed images)
- **Pull requests**: Full builds (all 5 images)
- **Never pushes to registry** - validation only

### Release Workflow (`release.yml`)

Builds and publishes Docker images when code is merged to main.

**Triggers:**
- Push to `main` branch only
- Only when relevant files change (terraform, docker, workflows)

**Jobs:**

```
┌─────────────────┐
│ validate        │ ← Quick OpenTofu validation
└────────┬────────┘
         │
┌────────▼────────┐
│ docker-release  │ ← Build & push all images (matrix: all 5 services)
└────────┬────────┘
         │
┌────────▼────────┐
│ release-summary │ ← Report published images
└─────────────────┘
```

**Behavior:**
- **Always builds all images** - ensures registry consistency
- **Pushes to ghcr.io** with `latest` and SHA tags
- **Generates summary** with published image details

## Image Tagging Strategy

| Tag | Description |
|-----|-------------|
| `latest` | Current production version from `main` |
| `<sha>` | Commit-specific tag for traceability |

## Performance Optimizations

1. **Selective builds** - Feature branches only build changed images
2. **Full validation on PRs** - All images tested before merge
3. **Matrix strategy** - Images build in parallel (5 concurrent jobs)
4. **Per-service cache** - Each image has dedicated GitHub Actions cache
5. **fail-fast: false** - One failed build doesn't cancel others

## GitHub Flow Integration

```
feature/issue-X ──push──► CI (selective build, test)
        │
        └──PR──► CI (full build, test all)
                      │
                      └──merge──► Release (build & push all)
```

1. Create branch: `git checkout -b feature/issue-X-description`
2. Push changes - CI validates changed images
3. Open PR to `main` - CI builds and tests all images
4. Merge - Release workflow publishes to ghcr.io

## Local Testing

Test workflows locally using [act](https://github.com/nektos/act):

```bash
# Install act (macOS)
brew install act

# Run CI workflow
act push -W .github/workflows/ci.yml

# Run specific job
act -j tofu-validate
act -j docker-build
```

## Adding New Workflows

When adding new workflows:

1. Name the file descriptively
2. Add appropriate triggers and path filters
3. Include GitHub step summaries for visibility
4. Document the workflow in this README
5. Test locally with `act` if possible

## Making Images Public

GitHub packages default to private. To allow Incus to pull images without authentication:

1. Go to https://github.com/accuser/atlas/packages
2. Click on each package (caddy, grafana, loki, prometheus, step-ca)
3. Go to "Package settings"
4. Under "Danger Zone", change visibility to "Public"

This only needs to be done once per package after first publish.

## Related Documentation

- [CONTRIBUTING.md](../../CONTRIBUTING.md) - GitHub Flow workflow guide
- [CLAUDE.md](../../CLAUDE.md) - Project architecture
- [docker/README.md](../../docker/README.md) - Docker image details
