# Backup and Disaster Recovery

This document describes backup procedures and disaster recovery playbooks for the Atlas infrastructure.

## Table of Contents

- [Overview](#overview)
- [Backup Procedures](#backup-procedures)
  - [Storage Volume Backups](#storage-volume-backups)
  - [Service-Specific Backups](#service-specific-backups)
  - [Terraform State Backup](#terraform-state-backup)
- [Disaster Recovery](#disaster-recovery)
  - [Full Infrastructure Rebuild](#full-infrastructure-rebuild)
  - [Single Service Recovery](#single-service-recovery)
  - [Data Restoration](#data-restoration)
- [Backup Schedule Recommendations](#backup-schedule-recommendations)
- [Automated Snapshot Scheduling](#automated-snapshot-scheduling)
  - [Terraform-Managed Snapshots](#terraform-managed-snapshots-recommended)
  - [Manual Backup Script](#manual-backup-script-alternative)
- [Testing and Verification](#testing-and-verification)

## Overview

### Persistent Storage Volumes

| Service | Volume | Size | Data | Criticality |
|---------|--------|------|------|-------------|
| Grafana | grafana01-data | 10GB | Dashboards, users, preferences | Medium |
| Prometheus | prometheus01-data | 100GB | Metrics time-series data | Low (regenerable) |
| Loki | loki01-data | 50GB | Log data | Low (regenerable) |
| step-ca | step-ca01-data | 1GB | CA certificates, private keys | **Critical** |
| Alertmanager | alertmanager01-data | 1GB | Silences, notification state | Low |
| Mosquitto | mosquitto01-data | 5GB | Retained messages, subscriptions | Medium |
| Atlantis | atlantis01-data | 10GB | Plans cache, locks (optional) | Low |

### Recovery Objectives

| Scenario | RTO (Recovery Time) | RPO (Recovery Point) |
|----------|---------------------|----------------------|
| Single service failure | 15 minutes | Last backup |
| Full infrastructure rebuild | 1 hour | Last backup |
| step-ca key compromise | 2 hours | N/A (regenerate) |

## Backup Procedures

### Storage Volume Backups

#### List All Volumes

```bash
incus storage volume list local
```

#### Create Volume Snapshots

Snapshots are instant, copy-on-write backups stored within Incus:

```bash
# Snapshot a single volume
incus storage volume snapshot local grafana01-data backup-$(date +%Y%m%d)

# Snapshot all Atlas volumes
for vol in grafana01-data prometheus01-data loki01-data step-ca01-data alertmanager01-data mosquitto01-data atlantis01-data; do
  incus storage volume snapshot local "$vol" "backup-$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
done
```

#### List Volume Snapshots

```bash
incus storage volume show local grafana01-data
```

#### Export Volume to Tarball (Off-site Backup)

For off-site backups, export volumes to compressed tarballs:

```bash
# Export a volume (container must be stopped)
incus stop grafana01
incus storage volume export local grafana01-data grafana01-data-$(date +%Y%m%d).tar.gz
incus start grafana01

# Export all volumes
BACKUP_DIR="/backup/atlas/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

for service in grafana01 prometheus01 loki01 step-ca01 alertmanager01 mosquitto01 atlantis01; do
  incus stop "$service" 2>/dev/null || true
  incus storage volume export local "${service}-data" "$BACKUP_DIR/${service}-data.tar.gz" 2>/dev/null || true
  incus start "$service" 2>/dev/null || true
done
```

#### Restore Volume from Snapshot

```bash
# Restore from snapshot (container must be stopped)
incus stop grafana01
incus storage volume restore local grafana01-data backup-20241126
incus start grafana01
```

#### Import Volume from Tarball

```bash
# Import a volume backup
incus storage volume import local grafana01-data-20241126.tar.gz grafana01-data-restored

# Or replace existing (delete first)
incus stop grafana01
incus storage volume delete local grafana01-data
incus storage volume import local grafana01-data-20241126.tar.gz grafana01-data
incus start grafana01
```

### Service-Specific Backups

#### Grafana

Grafana dashboards can be exported via the API for version control:

```bash
# Export all dashboards to JSON files
incus exec grafana01 -- sh -c '
  for uid in $(curl -s http://localhost:3000/api/search | jq -r ".[].uid"); do
    curl -s "http://localhost:3000/api/dashboards/uid/$uid" > "/tmp/dashboard-$uid.json"
  done
'
incus file pull grafana01/tmp/dashboard-*.json ./grafana-dashboards/
```

**Recommendation:** Store dashboard JSON files in version control for easy recovery.

#### Prometheus

Prometheus supports snapshots via its admin API:

```bash
# Create a Prometheus snapshot (requires --web.enable-admin-api)
incus exec prometheus01 -- curl -XPOST http://localhost:9090/api/v1/admin/tsdb/snapshot

# The snapshot is stored in /prometheus/snapshots/
incus exec prometheus01 -- ls /prometheus/snapshots/
```

**Note:** Prometheus data is regenerable from scrape targets. Full backups are optional unless historical data is critical.

#### Loki

Loki data is stored in chunks. For backup:

```bash
# Stop Loki to ensure consistency
incus stop loki01
incus storage volume snapshot local loki01-data backup-$(date +%Y%m%d)
incus start loki01
```

**Note:** Log data is often regenerable from sources. Consider retention policies over full backups.

#### step-ca (Critical)

The step-ca private key is **critical security material**. Handle with care:

```bash
# Backup step-ca data (includes private keys!)
incus stop step-ca01
incus storage volume export local step-ca01-data step-ca01-backup-$(date +%Y%m%d).tar.gz
incus start step-ca01

# Encrypt the backup
gpg --symmetric --cipher-algo AES256 step-ca01-backup-$(date +%Y%m%d).tar.gz

# Store encrypted backup securely (off-site, separate from infrastructure)
```

**Security Considerations:**
- Never store CA private key backups unencrypted
- Store in a separate location from infrastructure backups
- Consider using a hardware security module (HSM) for production CAs
- Document the encryption passphrase securely (password manager, not in repo)

#### Mosquitto

```bash
# Backup retained messages and persistent subscriptions
incus stop mosquitto01
incus storage volume snapshot local mosquitto01-data backup-$(date +%Y%m%d)
incus start mosquitto01
```

### Terraform State Backup

The Terraform state is stored in an Incus storage bucket. Back it up separately:

```bash
# List state bucket contents
incus storage bucket list terraform-state

# Export the state bucket
incus storage bucket export terraform-state atlas-terraform-state ./terraform-state-backup-$(date +%Y%m%d).tar.gz
```

**Important:** The terraform state may contain sensitive values. Encrypt backups.

## Disaster Recovery

### Full Infrastructure Rebuild

If the entire infrastructure needs to be rebuilt from scratch:

#### Prerequisites
- Fresh Incus installation (`incus admin init`)
- Access to backup files
- `terraform.tfvars` with credentials (store securely outside infrastructure)
- `backend.hcl` credentials (if using remote state)

#### Procedure

1. **Bootstrap Terraform state storage:**
   ```bash
   make bootstrap
   ```

2. **Restore Terraform state (if available):**
   ```bash
   # Import state bucket backup
   incus storage bucket import terraform-state ./terraform-state-backup.tar.gz atlas-terraform-state
   ```

3. **Initialize and apply Terraform:**
   ```bash
   make init
   make apply
   ```

4. **Restore data volumes:**
   ```bash
   # Stop services
   for svc in grafana01 prometheus01 loki01 step-ca01 alertmanager01 mosquitto01 atlantis01; do
     incus stop "$svc" 2>/dev/null || true
   done

   # Import volume backups
   for svc in grafana01 prometheus01 loki01 step-ca01 alertmanager01 mosquitto01 atlantis01; do
     incus storage volume delete local "${svc}-data" 2>/dev/null || true
     incus storage volume import local "./${svc}-data.tar.gz" "${svc}-data" 2>/dev/null || true
   done

   # Start services
   for svc in grafana01 prometheus01 loki01 step-ca01 alertmanager01 mosquitto01 atlantis01; do
     incus start "$svc" 2>/dev/null || true
   done
   ```

5. **Verify services:**
   ```bash
   incus list
   # Check each service's health endpoint
   ```

### Single Service Recovery

To recover a single failed service:

#### Option 1: Rebuild from Terraform (data loss)

```bash
cd terraform

# Taint the resource to force recreation
tofu taint 'module.grafana01.incus_instance.grafana'

# Apply to recreate
tofu apply
```

#### Option 2: Restore from Snapshot (no data loss)

```bash
# Stop the service
incus stop grafana01

# Restore volume from snapshot
incus storage volume restore local grafana01-data backup-20241126

# Start the service
incus start grafana01
```

#### Option 3: Restore from Backup Tarball

```bash
# Stop and remove
incus stop grafana01
incus storage volume delete local grafana01-data

# Import backup
incus storage volume import local ./grafana01-data.tar.gz grafana01-data

# Recreate container (volume already exists, Terraform will attach it)
cd terraform && tofu apply
```

### Data Restoration

#### Restore Grafana Dashboards from JSON

If dashboards were exported to JSON:

```bash
# Copy dashboard files into container
incus file push ./grafana-dashboards/*.json grafana01/tmp/

# Import via API
incus exec grafana01 -- sh -c '
  for f in /tmp/dashboard-*.json; do
    curl -X POST -H "Content-Type: application/json" \
      -d "{\"dashboard\": $(cat $f | jq .dashboard), \"overwrite\": true}" \
      http://admin:password@localhost:3000/api/dashboards/db
  done
'
```

#### Restore step-ca After Key Compromise

If the CA private key is compromised, you must regenerate (not restore):

1. **Stop step-ca:**
   ```bash
   incus stop step-ca01
   ```

2. **Delete the compromised data:**
   ```bash
   incus storage volume delete local step-ca01-data
   ```

3. **Recreate step-ca:**
   ```bash
   cd terraform && tofu apply
   ```

4. **Retrieve new CA fingerprint:**
   ```bash
   incus exec step-ca01 -- cat /home/step/fingerprint
   ```

5. **Update all services using the CA** with the new fingerprint.

6. **Revoke and reissue all certificates** issued by the old CA.

## Backup Schedule Recommendations

| Data | Frequency | Retention | Method |
|------|-----------|-----------|--------|
| step-ca | Weekly | 4 weeks | Encrypted export, off-site |
| Grafana | Daily | 7 days | Snapshot |
| Grafana dashboards | On change | Git history | JSON export to repo |
| Prometheus | Weekly | 2 weeks | Snapshot (optional) |
| Loki | Weekly | 2 weeks | Snapshot (optional) |
| Alertmanager | Daily | 7 days | Snapshot |
| Mosquitto | Daily | 7 days | Snapshot |
| Atlantis | Weekly | 2 weeks | Snapshot (optional) |
| Terraform state | Daily | 30 days | Bucket export |

## Automated Snapshot Scheduling

### Terraform-Managed Snapshots (Recommended)

Each module supports automatic snapshot scheduling via Incus native features. Snapshots are managed declaratively in Terraform and disabled by default.

#### Enabling Snapshots

Add snapshot configuration to module instances in `terraform/main.tf`:

```hcl
module "grafana01" {
  source = "./modules/grafana"

  # ... existing configuration ...

  # Enable automatic snapshots
  enable_snapshots   = true
  snapshot_schedule  = "@daily"    # or cron: "0 2 * * *"
  snapshot_expiry    = "7d"        # Keep for 7 days
  snapshot_pattern   = "auto-{{creation_date}}"
}
```

#### Default Schedules by Service

| Service | Default Schedule | Default Retention | Rationale |
|---------|-----------------|-------------------|-----------|
| Grafana | @daily | 7d | Dashboards and user preferences |
| Alertmanager | @daily | 7d | Silences and notification state |
| Mosquitto | @daily | 7d | Retained messages |
| Prometheus | @weekly | 2w | Large volume, data regenerable |
| Loki | @weekly | 2w | Large volume, logs regenerable |
| step-ca | @weekly | 4w | Critical CA data, longer retention |

#### Schedule Formats

- `@hourly` - Every hour
- `@daily` - Every day at midnight
- `@weekly` - Every week on Sunday
- `@monthly` - First day of each month
- Cron expressions: `"0 2 * * *"` (2 AM daily)

#### Expiry Formats

- `7d` - 7 days
- `4w` - 4 weeks
- `3m` - 3 months

#### Verifying Snapshots

```bash
# List snapshots for a volume
incus storage volume info local grafana01-data

# List all snapshots across volumes
for vol in grafana01-data prometheus01-data loki01-data step-ca01-data alertmanager01-data mosquitto01-data atlantis01-data; do
  echo "=== $vol ==="
  incus storage volume show local "$vol" | grep -A5 "snapshots:" 2>/dev/null || echo "  (volume not found)"
done
```

### Manual Backup Script (Alternative)

For environments where Terraform-managed snapshots aren't suitable, use a cron job:

```bash
#!/bin/bash
# /usr/local/bin/atlas-backup.sh

BACKUP_DIR="/backup/atlas/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Snapshot all volumes
for vol in grafana01-data prometheus01-data loki01-data step-ca01-data alertmanager01-data mosquitto01-data atlantis01-data; do
  incus storage volume snapshot local "$vol" "daily-$(date +%Y%m%d)" 2>/dev/null || true
done

# Clean old snapshots (keep 7 days)
for vol in grafana01-data prometheus01-data loki01-data step-ca01-data alertmanager01-data mosquitto01-data atlantis01-data; do
  incus storage volume show local "$vol" | grep -E "daily-[0-9]{8}" | while read snap; do
    snap_date=$(echo "$snap" | grep -oE "[0-9]{8}")
    if [[ $(date -d "$snap_date" +%s) -lt $(date -d "7 days ago" +%s) ]]; then
      incus storage volume delete local "$vol/$snap" 2>/dev/null || true
    fi
  done
done

# Weekly: Export step-ca (encrypted) for off-site
if [[ $(date +%u) -eq 7 ]]; then
  incus stop step-ca01
  incus storage volume export local step-ca01-data "$BACKUP_DIR/step-ca01-data.tar.gz"
  incus start step-ca01
  gpg --batch --yes --symmetric --cipher-algo AES256 \
    --passphrase-file /root/.backup-passphrase \
    "$BACKUP_DIR/step-ca01-data.tar.gz"
  rm "$BACKUP_DIR/step-ca01-data.tar.gz"
fi

echo "Backup completed: $BACKUP_DIR"
```

Add to crontab:
```bash
# Run daily at 2 AM
0 2 * * * /usr/local/bin/atlas-backup.sh >> /var/log/atlas-backup.log 2>&1
```

## Testing and Verification

### Verify Backup Integrity

```bash
# Test tarball integrity
tar -tzf grafana01-data.tar.gz > /dev/null && echo "OK" || echo "CORRUPTED"

# Test encrypted backup
gpg --decrypt step-ca01-backup.tar.gz.gpg | tar -tz > /dev/null
```

### Disaster Recovery Drill

Perform quarterly DR drills:

1. **Document current state:**
   ```bash
   incus list > pre-drill-state.txt
   cd terraform && tofu output > pre-drill-outputs.txt
   ```

2. **Simulate failure** (in a test environment):
   ```bash
   incus delete grafana01 --force
   incus storage volume delete local grafana01-data
   ```

3. **Execute recovery procedure** and time it.

4. **Verify service functionality.**

5. **Document results** and update procedures as needed.

### Recovery Time Benchmarks

Track recovery times to validate RTO targets:

| Scenario | Target RTO | Last Tested | Actual Time |
|----------|------------|-------------|-------------|
| Single service (snapshot) | 15 min | | |
| Single service (tarball) | 30 min | | |
| Full rebuild (no data) | 30 min | | |
| Full rebuild (with data) | 1 hour | | |

## Makefile Targets

Quick backup operations are available via Make:

```bash
# Create snapshots of all volumes
make backup-snapshot

# Export all volumes to tarballs
make backup-export

# List all snapshots
make backup-list
```

See the [Makefile](Makefile) for implementation details.
