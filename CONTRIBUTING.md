# Contributing to Atlas

Thank you for your interest in contributing to the Atlas infrastructure project!

## GitHub Flow Workflow

We use **GitHub Flow** with `develop` as our primary development branch. This is a simple, branch-based workflow that supports continuous delivery.

### Branch Structure

- **`main`** - Production-ready code. Protected branch.
- **`develop`** - Main development branch. All feature branches are created from and merged back to this branch.
- **`feature/*`** or **`fix/*`** - Short-lived branches for specific features or fixes.

### Workflow Steps

#### 1. Create a Branch from `develop`

Always create your feature/fix branch from the latest `develop`:

```bash
# Make sure you're on develop and it's up to date
git checkout develop
git pull origin develop

# Create a new branch for your work
git checkout -b feature/issue-1-fix-grafana-password
# or
git checkout -b fix/issue-4-shell-script-security
```

**Branch Naming Convention:**
- `feature/issue-X-short-description` - For new features
- `fix/issue-X-short-description` - For bug fixes
- `docs/issue-X-short-description` - For documentation updates
- `refactor/issue-X-short-description` - For code refactoring
- `test/issue-X-short-description` - For test additions/improvements

#### 2. Make Your Changes

- Make focused, logical commits
- Write clear commit messages
- Test your changes locally
- Run OpenTofu validation: `make plan`
- Format your code: `make format`

**Commit Message Format:**
```
<type>: <subject>

<body>

Fixes #<issue-number>
```

Example:
```
fix: remove hardcoded Grafana admin password

Move Grafana admin password from hardcoded value to Terraform variable.
Add sensitive variable declaration and update terraform.tfvars.example.

Fixes #1
```

#### 3. Push Your Branch

```bash
git push -u origin feature/issue-1-fix-grafana-password
```

#### 4. Create a Pull Request

Create a PR targeting the `develop` branch:

```bash
gh pr create --base develop --title "Fix: Remove hardcoded Grafana admin password" --body "Fixes #1"
```

Or use the GitHub web interface.

**Pull Request Guidelines:**
- Target `develop` branch (not `main`)
- Reference the issue number in the PR description (e.g., "Fixes #1")
- Provide a clear description of what changed and why
- Include testing steps if applicable
- Wait for CI checks to pass
- Request review if needed

#### 5. Address Review Feedback

If reviewers request changes:

```bash
# Make changes locally
git add .
git commit -m "address review feedback"
git push
```

#### 6. Merge to `develop`

Once approved and CI passes:
- Squash and merge or create a merge commit (project preference)
- Delete the feature branch after merging

#### 7. Release to `main`

Periodically, when `develop` is stable and ready for release:
- Create a PR from `develop` to `main`
- This triggers production deployment
- Tag the release on `main`

## Development Guidelines

### Before You Start

1. Check if an issue exists for your change. If not, create one.
2. Comment on the issue to let others know you're working on it.
3. Make sure you have a local development environment set up.

### Code Standards

**OpenTofu:**
- Run `tofu fmt` before committing
- Run `tofu validate` to ensure valid configuration
- Use meaningful variable names and descriptions
- Add comments for complex logic
- Follow module structure conventions

**Docker:**
- Pin base image versions (no `:latest`)
- Use multi-stage builds where appropriate
- Document any custom build arguments
- Keep images minimal and secure

**Shell Scripts:**
- Use `#!/usr/bin/env bash` shebang
- Add `set -euo pipefail` for safety
- Use meaningful variable names
- Add comments for complex operations
- Test scripts before committing

### Testing

Before submitting a PR:

```bash
# Format OpenTofu files
make format

# Validate OpenTofu configuration
cd terraform && tofu validate

# Run OpenTofu plan (requires valid terraform.tfvars)
make plan

# Build Docker images locally (optional)
make build-all
```

### Security Considerations

- Never commit secrets or sensitive data
- Use OpenTofu sensitive variables for credentials
- Follow principle of least privilege
- Review security implications of network/firewall changes
- Run security scans on Docker images

## Pull Request Template

When creating a PR, please include:

- **Description:** What does this PR do?
- **Motivation:** Why is this change needed?
- **Testing:** How was this tested?
- **Issues:** Fixes #X, Closes #Y
- **Breaking Changes:** Any breaking changes?
- **Checklist:**
  - [ ] Code follows project standards
  - [ ] Tests pass locally
  - [ ] Documentation updated if needed
  - [ ] No secrets or sensitive data committed

## Getting Help

- Check existing issues and PRs
- Read the [CLAUDE.md](CLAUDE.md) for project architecture
- Ask questions in issue comments
- Reach out to maintainers if stuck

## Code Review Process

- All PRs require passing CI checks
- PRs should be reviewed by at least one maintainer (project preference)
- Address feedback promptly
- Keep PRs focused and reasonably sized
- Be respectful and constructive in reviews

### Reviewing Dependabot PRs

Dependabot automatically creates PRs for Docker base image updates. When reviewing these:

**1. Check the changelog:**
- Review the upstream release notes for the new version
- Look for breaking changes or security fixes
- Verify compatibility with our configuration

**2. Verify CI passes:**
- Ensure all CI checks pass (build, tofu validate)
- Review any test failures carefully

**3. Test locally (for major updates):**
```bash
# Pull the PR branch
gh pr checkout <pr-number>

# Build the updated image locally
make build-<service>

# Test with OpenTofu
make plan
```

**4. Merge strategy:**
- **Patch updates (x.x.N)**: Usually safe to merge after CI passes
- **Minor updates (x.N.x)**: Review changelog, merge if no breaking changes
- **Major updates (N.x.x)**: Test thoroughly, may require configuration changes

**5. Post-merge:**
- Monitor deployed services for issues
- Roll back if problems are detected
- Update documentation if configuration changed

## Release Process

1. **Develop** - Continuous integration, all features merged here
2. **Staging** (optional) - Deploy from `develop` for testing
3. **Main** - Production releases, tagged with semantic versions
4. **Tagging** - Use semantic versioning (v1.2.3)

Example release workflow:
```bash
# Create release PR
gh pr create --base main --head develop --title "Release v1.2.0"

# After merge to main
git checkout main
git pull
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

## Community Guidelines

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Follow the code of conduct (if applicable)

## Questions?

If you have questions about contributing, please:
- Open an issue with the `question` label
- Refer to project documentation
- Contact maintainers

Thank you for contributing to Atlas!
