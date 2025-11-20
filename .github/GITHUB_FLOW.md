# GitHub Flow Quick Reference

## Branch Strategy

```
main (production)
  └── develop (development) ← Base for all feature branches
        ├── feature/issue-1-fix-password
        ├── feature/issue-2-remote-state
        └── fix/issue-4-shell-script
```

## Starting New Work

```bash
# 1. Switch to develop and update
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/issue-X-short-description

# Examples:
# git checkout -b feature/issue-1-fix-grafana-password
# git checkout -b fix/issue-4-shell-script-security
# git checkout -b docs/update-readme
```

## Making Changes

```bash
# 3. Make your changes
# Edit files, test locally

# 4. Stage and commit
git add .
git commit -m "fix: descriptive commit message

More details about the change if needed.

Fixes #X"

# 5. Push to GitHub
git push -u origin feature/issue-X-short-description
```

## Creating Pull Request

```bash
# Using GitHub CLI (recommended)
gh pr create --base develop --title "Fix: Descriptive title" --body "Fixes #X

Description of changes"

# Or using web interface:
# 1. Go to https://github.com/accuser/atlas/pulls
# 2. Click "New pull request"
# 3. Set base: develop, compare: your-branch
# 4. Fill in title and description
```

## After PR is Merged

```bash
# 1. Switch back to develop
git checkout develop

# 2. Pull latest changes
git pull origin develop

# 3. Delete local feature branch
git branch -d feature/issue-X-short-description

# 4. Delete remote branch (if not auto-deleted)
git push origin --delete feature/issue-X-short-description
```

## Branch Naming Conventions

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feature/` | New features | `feature/issue-10-add-headers` |
| `fix/` | Bug fixes | `fix/issue-1-password-leak` |
| `docs/` | Documentation | `docs/issue-15-update-readme` |
| `refactor/` | Code refactoring | `refactor/issue-14-bool-types` |
| `test/` | Test additions | `test/add-integration-tests` |

## Commit Message Format

```
<type>: <subject>

<body>

Fixes #<issue-number>
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `refactor` - Code refactoring
- `test` - Adding tests
- `chore` - Maintenance tasks

**Examples:**

```
fix: remove hardcoded Grafana admin password

Move password to Terraform variable with sensitive flag.
Update terraform.tfvars.example with placeholder.

Fixes #1
```

```
feat: add security headers to Caddy

Implement HSTS, X-Frame-Options, CSP headers.
Improves security posture for public endpoints.

Fixes #10
```

## CI/CD Behavior

| Event | What Happens |
|-------|--------------|
| Push to feature branch | Validation only (no image push) |
| PR to develop | Validation + builds (no image push) |
| Merge to develop | Validation + builds + push develop tags |
| Merge to main | Validation + builds + push latest tags |

## Common Issues

### Wrong base branch
**Problem:** Created PR targeting `main` instead of `develop`

**Solution:**
```bash
# On GitHub PR page, click "Edit" next to base branch
# Change from "main" to "develop"
```

### Branch out of date
**Problem:** `develop` has moved ahead since you branched

**Solution:**
```bash
# On your feature branch
git fetch origin
git rebase origin/develop

# Or merge instead of rebase
git merge origin/develop

# Resolve conflicts if any, then push
git push --force-with-lease
```

### Forgot to branch from develop
**Problem:** Created branch from `main` instead of `develop`

**Solution:**
```bash
# On your feature branch
git rebase --onto develop main feature/issue-X-description
git push --force-with-lease
```

## Release Process

When `develop` is ready for production:

```bash
# 1. Create release PR
gh pr create --base main --head develop --title "Release v1.2.0"

# 2. After approval and merge, tag the release
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0

# 3. Update develop from main
git checkout develop
git merge main
git push origin develop
```

## Tips

- **Keep PRs focused** - One issue per PR when possible
- **Link issues** - Always use "Fixes #X" in PR description
- **Wait for CI** - Don't merge until checks pass
- **Update often** - Pull from develop regularly
- **Delete branches** - Clean up after merging
- **Review your own PR** - Check the diff before requesting review

## Quick Commands

```bash
# See all branches
git branch -a

# See current branch
git branch --show-current

# See status
git status

# See recent commits
git log --oneline -10

# See what changed
git diff develop

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Discard local changes
git restore .
```

## Resources

- Full guide: [CONTRIBUTING.md](../CONTRIBUTING.md)
- Project architecture: [CLAUDE.md](../CLAUDE.md)
- CI/CD details: [workflows/README.md](workflows/README.md)
