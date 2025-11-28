# Troubleshooting Guide

This guide covers common issues and their solutions when working with the Atlas infrastructure.

## Table of Contents

- [Certificate Issues](#certificate-issues)
- [Network Connectivity](#network-connectivity)
- [Storage Issues](#storage-issues)
- [Service-Specific Issues](#service-specific-issues)
- [Deployment Issues](#deployment-issues)
- [Useful Commands](#useful-commands)

---

## Certificate Issues

### Let's Encrypt Rate Limits

**Symptoms:**
- Caddy fails to obtain certificates
- Error messages mentioning "rate limit" or "too many requests"

**Cause:** Let's Encrypt has [rate limits](https://letsencrypt.org/docs/rate-limits/) including 50 certificates per registered domain per week.

**Solutions:**
1. Wait for the rate limit to reset (usually 1 week)
2. Use Let's Encrypt staging environment for testing:
   ```hcl
   # In Caddyfile, add:
   acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
   ```
3. Check for duplicate certificate requests in logs:
   ```bash
   incus exec caddy01 -- cat /var/log/caddy/access.log | grep -i acme
   ```

### Cloudflare API Token Validation

**Symptoms:**
- DNS-01 challenge fails
- "Invalid API token" errors

**Diagnosis:**
```bash
# Test token permissions
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

**Solutions:**
1. Verify the token has `Zone:DNS:Edit` and `Zone:Zone:Read` permissions
2. Check the token is scoped to the correct zone
3. Regenerate the token if it has expired
4. Ensure the token is correctly set in `terraform.tfvars`:
   ```hcl
   cloudflare_api_token = "your-token-here"
   ```

### step-ca Initialization Failures

**Symptoms:**
- step-ca container fails to start
- Missing fingerprint file
- "CA not initialized" errors

**Diagnosis:**
```bash
# Check container status
incus info step-ca01

# View container logs
incus exec step-ca01 -- cat /home/step/logs/ca.log 2>/dev/null || \
  incus exec step-ca01 -- journalctl -u step-ca
```

**Solutions:**
1. Check if the data volume has correct permissions:
   ```bash
   incus exec step-ca01 -- ls -la /home/step/
   ```
2. Reinitialize the CA (warning: destroys existing certificates):
   ```bash
   incus stop step-ca01
   incus storage volume delete local step-ca01-data
   tofu apply  # Recreates the volume and container
   ```
3. Verify environment variables:
   ```bash
   incus exec step-ca01 -- env | grep STEPCA
   ```

### Certificate Renewal Problems

**Symptoms:**
- Services lose TLS after ~24 hours
- "Certificate expired" errors

**Cause:** Short-lived certificates (24h default) require automatic renewal.

**Solutions:**
1. Restart the container to trigger renewal:
   ```bash
   incus restart grafana01
   ```
2. Check if step-ca is accessible:
   ```bash
   incus exec grafana01 -- curl -k https://step-ca01.incus:9000/health
   ```
3. Verify the CA fingerprint matches:
   ```bash
   incus exec step-ca01 -- cat /home/step/fingerprint
   ```

---

## Network Connectivity

### Container DNS Resolution

**Symptoms:**
- Containers cannot resolve `.incus` hostnames
- `ping prometheus01.incus` fails
- "Name or service not known" errors

**Diagnosis:**
```bash
# Test DNS resolution
incus exec grafana01 -- nslookup prometheus01.incus

# Check /etc/resolv.conf
incus exec grafana01 -- cat /etc/resolv.conf
```

**Solutions:**
1. Verify the container is on the correct network:
   ```bash
   incus info grafana01 | grep -A5 "Network"
   ```
2. Check if the Incus DNS server is running:
   ```bash
   incus network show management
   ```
3. Restart the container to refresh network configuration:
   ```bash
   incus restart grafana01
   ```

### Inter-Service Communication Failures

**Symptoms:**
- Prometheus cannot scrape targets
- Grafana cannot connect to datasources
- "Connection refused" or "No route to host" errors

**Diagnosis:**
```bash
# Test connectivity from Prometheus
incus exec prometheus01 -- wget -qO- http://grafana01.incus:3000/api/health

# Check if target port is listening
incus exec grafana01 -- netstat -tlnp | grep 3000
```

**Solutions:**
1. Verify both containers are on the same network:
   ```bash
   incus list -c n,s,4,N
   ```
2. Check if the service is bound to the correct interface (0.0.0.0, not 127.0.0.1)
3. Review firewall rules inside the container:
   ```bash
   incus exec grafana01 -- iptables -L -n
   ```

### Firewall/NAT Issues

**Symptoms:**
- External access to services fails
- Containers cannot reach the internet

**Diagnosis:**
```bash
# Check NAT configuration
incus network show management | grep nat

# Test external connectivity from container
incus exec grafana01 -- ping -c 1 8.8.8.8
```

**Solutions:**
1. Verify NAT is enabled on the network:
   ```hcl
   # In terraform.tfvars
   management_network_nat = true
   ```
2. Check host firewall rules:
   ```bash
   sudo iptables -L -n | grep -i incus
   ```
3. Verify IP forwarding is enabled:
   ```bash
   cat /proc/sys/net/ipv4/ip_forward  # Should be 1
   ```

### Incus Network Troubleshooting

**Symptoms:**
- Networks fail to create
- IP address conflicts

**Diagnosis:**
```bash
# List all networks
incus network list

# Show network details
incus network show management

# Check for IP conflicts
ip addr show | grep "10.50.0"
```

**Solutions:**
1. Use non-conflicting IP ranges in `terraform.tfvars`
2. Delete and recreate the network:
   ```bash
   incus network delete management
   tofu apply
   ```

---

## Storage Issues

### Volume Full Scenarios

**Symptoms:**
- Services stop writing data
- "No space left on device" errors
- Prometheus or Loki stop ingesting

**Diagnosis:**
```bash
# Check volume usage
incus storage volume info local prometheus01-data

# Check filesystem inside container
incus exec prometheus01 -- df -h /prometheus
```

**Solutions:**
1. Increase volume size:
   ```hcl
   # In main.tf
   data_volume_size = "200GB"  # Increase from 100GB
   ```
   Then apply:
   ```bash
   tofu apply
   ```
2. Reduce retention to free space:
   ```hcl
   retention_time = "15d"  # Reduce from 30d
   ```
3. Manually clean old data:
   ```bash
   # For Prometheus (dangerous - use retention instead)
   incus exec prometheus01 -- rm -rf /prometheus/wal/*
   ```

### Permission Errors

**Symptoms:**
- Services fail to write to mounted volumes
- "Permission denied" errors in logs

**Diagnosis:**
```bash
# Check volume ownership
incus exec prometheus01 -- ls -la /prometheus

# Check running user
incus exec prometheus01 -- id
```

**Solutions:**
1. Verify initial volume ownership in module configuration:
   ```hcl
   config = {
     "initial.uid"  = "65534"  # nobody user for Prometheus
     "initial.gid"  = "65534"
   }
   ```
2. Fix ownership manually:
   ```bash
   incus exec prometheus01 -- chown -R nobody:nobody /prometheus
   ```
3. Check if Incus version supports `initial.uid` (requires Incus 6.8+)

### ZFS-Specific Issues

**Symptoms:**
- Volume operations fail
- "dataset is busy" errors

**Diagnosis:**
```bash
# List ZFS datasets
sudo zfs list

# Check for busy datasets
sudo lsof +D /var/lib/incus/storage-pools/local
```

**Solutions:**
1. Stop containers using the volume before operations
2. Check for ZFS pool issues:
   ```bash
   sudo zpool status
   ```
3. Clear ZFS cache:
   ```bash
   sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
   ```

### Backup/Restore Failures

**Symptoms:**
- Snapshot creation fails
- Export operations timeout
- Restore fails with errors

**Diagnosis:**
```bash
# List existing snapshots
incus storage volume snapshot list local prometheus01-data

# Check storage pool space
incus storage info local
```

**Solutions:**
1. Ensure enough free space for snapshots (at least 20% free)
2. Stop the container before export:
   ```bash
   incus stop prometheus01
   incus storage volume export local prometheus01-data backup.tar.gz
   incus start prometheus01
   ```
3. For corrupted snapshots, delete and recreate:
   ```bash
   incus storage volume snapshot delete local prometheus01-data snap0
   ```

### Automated Snapshot Issues

**Symptoms:**
- Scheduled snapshots not being created
- Snapshots not expiring as configured

**Diagnosis:**
```bash
# Check volume snapshot configuration
incus storage volume show local prometheus01-data | grep snapshot

# Verify Terraform configuration
cd terraform && tofu show | grep -A5 "enable_snapshots"
```

**Solutions:**
1. Verify `enable_snapshots = true` in the module configuration
2. Check schedule format is valid (e.g., `@daily`, `@weekly`, or cron expression)
3. Verify expiry format (e.g., `7d`, `4w`, `3m`)
4. Re-apply Terraform to update volume configuration:
   ```bash
   tofu apply
   ```

---

## Service-Specific Issues

### Grafana Datasource Configuration

**Symptoms:**
- "Data source is not working" errors
- Empty dashboards
- "Bad Gateway" from Prometheus datasource

**Diagnosis:**
```bash
# Test Prometheus connectivity from Grafana
incus exec grafana01 -- wget -qO- http://prometheus01.incus:9090/api/v1/query?query=up

# Check Grafana logs
incus exec grafana01 -- cat /var/log/grafana/grafana.log | tail -50
```

**Solutions:**
1. Verify datasource URL uses container hostname:
   ```
   http://prometheus01.incus:9090
   ```
2. Check if Prometheus is healthy:
   ```bash
   curl http://prometheus01.incus:9090/-/ready
   ```
3. Review provisioned datasources:
   ```bash
   incus exec grafana01 -- cat /etc/grafana/provisioning/datasources/datasources.yaml
   ```

### Prometheus Scrape Failures

**Symptoms:**
- Targets show as DOWN in Prometheus UI
- Missing metrics
- "context deadline exceeded" errors

**Diagnosis:**
```bash
# Check target status
curl -s http://prometheus01.incus:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'
```

**Solutions:**
1. Verify the target endpoint is accessible:
   ```bash
   incus exec prometheus01 -- wget -qO- http://target.incus:port/metrics | head
   ```
2. Check scrape configuration:
   ```bash
   incus exec prometheus01 -- cat /etc/prometheus/prometheus.yml
   ```
3. Increase scrape timeout for slow targets:
   ```yaml
   scrape_configs:
     - job_name: 'slow-target'
       scrape_timeout: 30s
   ```

### Loki Ingestion Issues

**Symptoms:**
- Logs not appearing in Grafana
- "429 Too Many Requests" errors
- High memory usage

**Diagnosis:**
```bash
# Check Loki health
curl http://loki01.incus:3100/ready

# View Loki metrics
curl http://loki01.incus:3100/metrics | grep loki_ingester
```

**Solutions:**
1. Check if Loki is receiving logs:
   ```bash
   curl -G -s http://loki01.incus:3100/loki/api/v1/query --data-urlencode 'query={job=~".+"}' | jq
   ```
2. Increase ingestion limits if needed
3. Check disk space - Loki needs space for WAL:
   ```bash
   incus exec loki01 -- df -h /loki
   ```

### Caddy Routing Problems

**Symptoms:**
- 502 Bad Gateway errors
- "No upstreams available"
- Wrong service responding

**Diagnosis:**
```bash
# Check Caddyfile configuration
incus exec caddy01 -- cat /etc/caddy/Caddyfile

# Test backend connectivity
incus exec caddy01 -- wget -qO- http://grafana01.incus:3000/api/health
```

**Solutions:**
1. Verify the upstream service is running:
   ```bash
   incus list | grep grafana
   ```
2. Check Caddy logs:
   ```bash
   incus exec caddy01 -- cat /var/log/caddy/access.log | tail -20
   ```
3. Reload Caddy configuration:
   ```bash
   incus exec caddy01 -- caddy reload --config /etc/caddy/Caddyfile
   ```

---

## Deployment Issues

### OpenTofu State Corruption

**Symptoms:**
- "State file is locked" errors
- Inconsistent state warnings
- Resources exist but Terraform doesn't know about them

**Diagnosis:**
```bash
# Check state lock
cd terraform && tofu force-unlock LOCK_ID

# List resources in state
tofu state list
```

**Solutions:**
1. Force unlock if previous operation was interrupted:
   ```bash
   tofu force-unlock -force LOCK_ID
   ```
2. Refresh state to match reality:
   ```bash
   tofu refresh
   ```
3. Import existing resources:
   ```bash
   tofu import 'module.grafana01.incus_instance.grafana' grafana01
   ```
4. For severe corruption, rebuild state:
   ```bash
   # Backup current state
   cp terraform.tfstate terraform.tfstate.backup
   # Remove corrupted state
   rm terraform.tfstate
   # Import resources one by one
   ```

### Image Pull Failures

**Symptoms:**
- "Image not found" errors
- Timeout during image download
- Authentication failures for ghcr.io

**Diagnosis:**
```bash
# List cached images
incus image list

# Test image pull manually
incus image copy ghcr:accuser/atlas/grafana:latest local: --alias test-grafana
```

**Solutions:**
1. Check network connectivity:
   ```bash
   curl -I https://ghcr.io
   ```
2. Clear cached images and retry:
   ```bash
   incus image delete <fingerprint>
   tofu apply
   ```
3. For private registries, configure authentication:
   ```bash
   incus remote add myregistry https://registry.example.com --auth-type=bearer --token=TOKEN
   ```

### Resource Limit Errors

**Symptoms:**
- Container fails to start
- "Insufficient resources" errors
- OOM kills

**Diagnosis:**
```bash
# Check host resources
incus info --resources

# Check container limits
incus config show grafana01 | grep limits
```

**Solutions:**
1. Reduce container limits:
   ```hcl
   cpu_limit    = "1"
   memory_limit = "512MB"
   ```
2. Stop unused containers to free resources
3. Check for memory leaks in containers:
   ```bash
   incus exec grafana01 -- top -b -n 1 | head -20
   ```

### Bootstrap Failures

**Symptoms:**
- `make bootstrap` fails
- Storage bucket creation errors
- Backend configuration issues

**Diagnosis:**
```bash
# Check bootstrap state
cd terraform/bootstrap && tofu state list

# Verify storage pool exists
incus storage list
```

**Solutions:**
1. Ensure Incus is properly initialized:
   ```bash
   incus admin init --dump  # Shows current config
   ```
2. Clean up and retry bootstrap:
   ```bash
   make clean-bootstrap
   make bootstrap
   ```
3. For storage bucket issues, check pool configuration:
   ```bash
   incus storage show local
   ```

---

## Useful Commands

### Container Management

```bash
# List all containers with status
incus list

# Detailed container info
incus info grafana01

# View container logs
incus exec grafana01 -- journalctl -f

# Access container shell
incus exec grafana01 -- /bin/sh

# Restart a container
incus restart grafana01

# Stop all containers
incus stop --all
```

### Network Diagnostics

```bash
# List networks
incus network list

# Show network details
incus network show management

# Test DNS resolution
incus exec grafana01 -- nslookup prometheus01.incus

# Test connectivity
incus exec grafana01 -- ping -c 3 prometheus01.incus

# Check container IP
incus list -c n,4
```

### Storage Operations

```bash
# List storage pools
incus storage list

# List volumes
incus storage volume list local

# Check volume usage
incus storage volume info local prometheus01-data

# Create snapshot
incus storage volume snapshot local prometheus01-data backup-$(date +%Y%m%d)

# List snapshots
incus storage volume snapshot list local prometheus01-data
```

### Service Health Checks

```bash
# Prometheus
curl -s http://prometheus01.incus:9090/-/ready

# Loki
curl -s http://loki01.incus:3100/ready

# Grafana
curl -s http://grafana01.incus:3000/api/health

# Caddy
curl -s http://caddy01.incus:2019/config/

# step-ca
incus exec step-ca01 -- step ca health --ca-url https://localhost:9000 --root /home/step/certs/root_ca.crt
```

### OpenTofu Operations

```bash
# Validate configuration
cd terraform && tofu validate

# Plan changes
tofu plan

# Apply changes
tofu apply

# Show current state
tofu show

# List resources
tofu state list

# View outputs
tofu output
```

### Log Viewing

```bash
# Grafana logs
incus exec grafana01 -- tail -f /var/log/grafana/grafana.log

# Prometheus logs
incus exec prometheus01 -- cat /proc/1/fd/1  # stdout

# Caddy logs
incus exec caddy01 -- tail -f /var/log/caddy/access.log

# Container system logs
incus exec grafana01 -- dmesg | tail -20
```

### Resource Monitoring

```bash
# Host resources
incus info --resources

# Container resource usage
incus info grafana01 | grep -A20 "Resources"

# Top processes in container
incus exec grafana01 -- top -b -n 1 | head -15

# Disk usage in container
incus exec prometheus01 -- df -h
```

---

## Getting Help

If you can't resolve an issue:

1. Check the [module READMEs](terraform/modules/) for service-specific documentation
2. Review [BACKUP.md](BACKUP.md) for data recovery procedures
3. Open an issue at https://github.com/accuser/atlas/issues with:
   - Description of the problem
   - Steps to reproduce
   - Relevant logs and error messages
   - Output of `incus list` and `tofu show`
