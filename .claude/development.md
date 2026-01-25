# Development Workflow

Development workflow, CI/CD, and contribution guidelines.

## GitHub Flow

All work happens on feature branches merged to `main`.

### Branch Naming

- `feature/issue-X-description` - New features
- `fix/issue-X-description` - Bug fixes
- `docs/issue-X-description` - Documentation
- `refactor/issue-X-description` - Code refactoring

### Standard Workflow

```bash
git checkout main
git pull origin main
git checkout -b feature/issue-1-description

# Make changes, test locally
make format
make plan

git add .
git commit -m "feat: description"
git push -u origin feature/issue-1-description
gh pr create --base main
```

### Commit Message Format

```
<type>: <subject>

<body>

Fixes #<issue-number>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

## Code Standards

### Terraform

- Run `make format` before committing
- Run `make plan` to validate changes
- Use meaningful variable names with descriptions
- Add comments for complex logic
- Follow existing module patterns for storage and snapshots

### Docker

- Pin base image versions (never use `:latest`)
- Use multi-stage builds where appropriate
- Keep images minimal and secure
- Document build arguments

### Shell Scripts

- Use `#!/usr/bin/env bash` shebang
- Add `set -euo pipefail` for safety
- Test scripts before committing
- Add comments for complex operations

## Testing Locally

```bash
# Format and validate
make format
cd environments/iapetus && tofu validate

# Plan changes
make plan                    # iapetus
ENV=cluster01 make plan      # cluster01

# Build custom images
cd docker/atlantis && docker build -t atlantis-local .
```

## Security

- Never commit secrets or credentials
- Use Terraform sensitive variables
- Follow principle of least privilege
- Review network/firewall change implications
- `terraform.tfvars` is gitignored - contains secrets

## CI/CD

### Automated Workflows

**On PR:**
- Terraform format check
- Terraform validate
- Docker image build test

**On merge to main:**
- Build and push Docker images with `:latest` tag
- Auto-update Dependabot PRs

### Dependabot

Automatically creates PRs for base image updates.

**Review checklist:**
1. Check upstream release notes
2. Verify CI passes
3. Test locally for major updates
4. Merge patch updates after CI, review minor/major updates carefully

## Pull Request Guidelines

- Target `main` branch
- Reference issue number: "Fixes #1"
- Provide clear description of changes
- Include testing steps
- Wait for CI checks to pass
- Address review feedback promptly

**Checklist:**
- [ ] Code follows standards
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] No secrets committed

## Release Process

Releases happen automatically on merge to `main`. Manual tags for significant milestones:

```bash
git checkout main
git pull
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

## Additional Resources

- Full details: [CONTRIBUTING.md](../CONTRIBUTING.md)
- Backup procedures: [BACKUP.md](../BACKUP.md)
