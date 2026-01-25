# Command Reference

Complete command reference for working with this repository.

## Makefile Operations

### Environment Selection

```bash
make <target>              # Targets iapetus (default)
ENV=cluster01 make <target> # Targets cluster01
```

### Bootstrap and Initialization

```bash
make bootstrap             # First-time setup: create S3 bucket for remote state
make init                  # Initialize Terraform with remote backend
```

Never run `tofu init` directly - always use `make init` or `./init.sh`.

### OpenTofu Operations

```bash
make validate              # Validate configuration
make plan                  # Show execution plan
make apply                 # Apply changes (asks for confirmation)
make destroy               # Destroy infrastructure (asks for confirmation)
make output                # Show output values
```

### Utilities

```bash
make format                # Format all .tf files
make clean                 # Remove build artifacts
make backup-snapshot       # Snapshot all storage volumes
```

## Direct OpenTofu

When working directly in an environment directory:

```bash
cd environments/iapetus    # or cluster01
tofu validate
tofu plan
tofu apply
tofu output
tofu state list
tofu state show <resource>
```

## Container Operations

### Service Management

```bash
incus exec <container> -- systemctl status <service>
incus exec <container> -- systemctl restart <service>
incus exec <container> -- journalctl -u <service> -f
incus exec <container> -- journalctl -u <service> --since "10 minutes ago"
```

### Container Management

```bash
incus list                          # List all containers
incus info <container>              # Show container details
incus exec <container> -- bash      # Shell into container
incus console <container>           # Attach to console
incus restart <container>           # Restart container
incus stop <container>              # Stop container
incus start <container>             # Start container
```

### Storage and Backups

```bash
incus storage volume list default   # List volumes
incus storage volume snapshot create default <volume> <snapshot-name>
incus storage volume snapshot list default <volume>
incus storage volume snapshot restore default <volume> <snapshot-name>
```

### Network Debugging

```bash
incus network list                  # List networks
incus network show <network>        # Show network config
incus exec <container> -- ip addr   # Show IPs
incus exec <container> -- ping <target>
incus exec <container> -- curl <url>
```

## Git Operations

### Standard Workflow

```bash
git checkout -b feature/description
# Make changes
git add .
git commit -m "fix: description"
git push -u origin feature/description
gh pr create --base main
```

### Viewing Changes

```bash
git status                          # Show working tree status
git diff                            # Show unstaged changes
git diff --staged                   # Show staged changes
git log --oneline -10               # Recent commits
```

## GitHub CLI

```bash
gh pr list                          # List PRs
gh pr view <number>                 # View PR details
gh pr checks                        # View PR checks
gh pr merge <number>                # Merge PR
gh workflow list                    # List workflows
gh workflow view <workflow>         # View workflow runs
```

## Docker (for Atlantis image)

```bash
cd docker/atlantis
docker build -t atlantis-local .
docker run --rm atlantis-local tofu version
```

## Troubleshooting Commands

### Check Service Health

```bash
# Prometheus
incus exec prometheus -- curl -s localhost:9090/-/healthy

# Loki
incus exec loki -- curl -s localhost:3100/ready

# Grafana
incus exec grafana -- curl -s localhost:3000/api/health

# Alertmanager
incus exec alertmanager -- curl -s localhost:9093/-/healthy
```

### View Logs

```bash
# All logs for a service
incus exec <container> -- journalctl -u <service>

# Follow logs
incus exec <container> -- journalctl -u <service> -f

# Since timestamp
incus exec <container> -- journalctl -u <service> --since "2026-01-20 10:00:00"

# Last N lines
incus exec <container> -- journalctl -u <service> -n 100
```

### Check Resource Usage

```bash
incus info <container>              # CPU, memory, disk usage
incus exec <container> -- df -h     # Disk usage inside container
incus exec <container> -- free -h   # Memory usage inside container
incus exec <container> -- top       # Process monitoring
```
