# GitHub Flow Quick Reference

## Branch Strategy

```
main (production)
  ├── feature/issue-1-fix-password
  ├── feature/issue-2-remote-state
  └── fix/issue-4-shell-script
```

## Starting New Work

```bash
# 1. Switch to main and update
git checkout main
git pull origin main

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
gh pr create --base main --title "Fix: Descriptive title" --body "Fixes #X

Description of changes"

# Or using web interface:
# 1. Go to https://github.com/accuser-dev/atlas/pulls
# 2. Click "New pull request"
# 3. Set base: main, compare: your-branch
# 4. Fill in title and description
```

## After PR is Merged

```bash
# 1. Switch back to main
git checkout main

# 2. Pull latest changes
git pull origin main

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
| PR to main | Validation + builds (no image push) |
| Merge to main | Validation + builds + push latest tags |

## Common Issues

### Branch out of date
**Problem:** `main` has moved ahead since you branched

**Solution:**
```bash
# On your feature branch
git fetch origin
git rebase origin/main

# Or merge instead of rebase
git merge origin/main

# Resolve conflicts if any, then push
git push --force-with-lease
```

## Release Process

Releases happen automatically when PRs are merged to `main`. For milestone releases:

```bash
# After significant changes are merged to main
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release version 1.2.0"
git push origin v1.2.0
```

## Tips

- **Keep PRs focused** - One issue per PR when possible
- **Link issues** - Always use "Fixes #X" in PR description
- **Wait for CI** - Don't merge until checks pass
- **Update often** - Pull from main regularly
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
git diff main

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Discard local changes
git restore .
```

## Resources

- Full guide: [CONTRIBUTING.md](../CONTRIBUTING.md)
- Project architecture: [CLAUDE.md](../CLAUDE.md)
- CI/CD details: [workflows/README.md](workflows/README.md)
