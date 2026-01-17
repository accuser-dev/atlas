# Ceph Module

Deploys a Ceph distributed storage cluster on an Incus cluster using separate containers for each daemon type.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Incus Cluster (3-node)                          │
├─────────────────┬─────────────────────┬─────────────────────────────┤
│     node01      │       node02        │          node03             │
├─────────────────┼─────────────────────┼─────────────────────────────┤
│ ┌─────────────┐ │ ┌─────────────┐     │ ┌─────────────┐             │
│ │ceph-mon-n01 │ │ │ceph-mon-n02 │     │ │ceph-mon-n03 │             │
│ │ (bootstrap) │ │ │             │     │ │             │             │
│ └─────────────┘ │ └─────────────┘     │ └─────────────┘             │
│ ┌─────────────┐ │                     │                             │
│ │ceph-mgr-n01 │ │                     │                             │
│ └─────────────┘ │                     │                             │
│ ┌─────────────┐ │ ┌─────────────┐     │ ┌─────────────┐             │
│ │ceph-osd-n01 │ │ │ceph-osd-n02 │     │ │ceph-osd-n03 │             │
│ │   (HDD)     │ │ │   (HDD)     │     │ │   (HDD)     │             │
│ └─────────────┘ │ └─────────────┘     │ └─────────────┘             │
│ ┌─────────────┐ │                     │                             │
│ │ceph-rgw-n01 │ │                     │                             │
│ │  (S3 API)   │ │                     │                             │
│ └─────────────┘ │                     │                             │
└─────────────────┴─────────────────────┴─────────────────────────────┘
```

## Components

| Daemon | Purpose | Container Type |
|--------|---------|----------------|
| **MON** | Cluster state, CRUSH map, authentication | Unprivileged |
| **MGR** | Monitoring, REST API, Prometheus metrics | Unprivileged |
| **OSD** | Data storage on block devices | **Privileged** (block device access) |
| **RGW** | S3-compatible object storage API | Unprivileged |

## Usage

```hcl
module "ceph" {
  source = "../../modules/ceph"

  cluster_name = "ceph"
  # cluster_fsid = ""  # Leave empty to auto-generate

  profiles     = [module.base.container_base_profile.name]
  storage_pool = "local"

  # Network configuration
  storage_network_name = "storage"
  public_network       = "10.40.0.0/24"

  # MON configuration (minimum 3 for quorum)
  # Keys are cluster node names for consistent naming
  mons = {
    "node01" = {
      target_node  = "node01"
      static_ip    = "10.40.0.11"
      is_bootstrap = true
    }
    "node02" = {
      target_node  = "node02"
      static_ip    = "10.40.0.12"
    }
    "node03" = {
      target_node  = "node03"
      static_ip    = "10.40.0.13"
    }
  }

  # MGR configuration
  mgrs = {
    "node01" = {
      target_node = "node01"
      static_ip   = "10.40.0.21"
    }
  }

  # OSD configuration (one per block device)
  osds = {
    "node01" = {
      target_node      = "node01"
      osd_block_device = "/dev/disk/by-id/wwn-0x5000c500b51f1abc"
      static_ip        = "10.40.0.31"
    }
    "node02" = {
      target_node      = "node02"
      osd_block_device = "/dev/disk/by-id/wwn-0x5000c500b51f28cc"
      static_ip        = "10.40.0.32"
    }
    "node03" = {
      target_node      = "node03"
      osd_block_device = "/dev/disk/by-id/wwn-0x5000c500b51f6508"
      static_ip        = "10.40.0.33"
    }
  }

  # RGW configuration (S3 API)
  rgws = {
    "node01" = {
      target_node = "node01"
      static_ip   = "10.40.0.41"
    }
  }
}
```

## Prerequisites

### 1. Storage Network on IncusOS

Configure the storage network on each IncusOS node:

```bash
# On each node, assign the storage NIC role
incus admin os network create storage parent=<interface>
```

### 2. Block Device Identification

Identify stable block device paths for OSDs:

```bash
incus admin os system storage show --target=node01
# Use /dev/disk/by-id/wwn-... paths for stability
```

## Post-Deployment Steps

### 1. Distribute Keys to Non-Bootstrap Containers

After the bootstrap MON is running, copy keys to other containers:

```bash
# From bootstrap MON to other MONs
incus file pull ceph-mon-node01/etc/ceph/ceph.client.admin.keyring /tmp/
incus file push /tmp/ceph.client.admin.keyring ceph-mon-node02/etc/ceph/
incus file push /tmp/ceph.client.admin.keyring ceph-mon-node03/etc/ceph/

# To MGR
incus file push /tmp/ceph.client.admin.keyring ceph-mgr-node01/etc/ceph/

# To OSDs (also need bootstrap-osd keyring)
incus file pull ceph-mon-node01/var/lib/ceph/bootstrap-osd/ceph.keyring /tmp/bootstrap-osd.keyring
for node in node01 node02 node03; do
  incus file push /tmp/ceph.client.admin.keyring ceph-osd-$node/etc/ceph/
  incus file push /tmp/bootstrap-osd.keyring ceph-osd-$node/var/lib/ceph/bootstrap-osd/ceph.keyring
done

# To RGW (also need bootstrap-rgw keyring)
incus file pull ceph-mon-node01/var/lib/ceph/bootstrap-rgw/ceph.keyring /tmp/bootstrap-rgw.keyring
incus file push /tmp/ceph.client.admin.keyring ceph-rgw-node01/etc/ceph/
incus file push /tmp/bootstrap-rgw.keyring ceph-rgw-node01/var/lib/ceph/bootstrap-rgw/ceph.keyring
```

### 2. Verify Cluster Health

```bash
incus exec ceph-mon-node01 -- ceph -s
incus exec ceph-mon-node01 -- ceph osd tree
```

### 3. Create S3 User

```bash
incus exec ceph-rgw-node01 -- radosgw-admin user create \
  --uid=myuser \
  --display-name="My User" \
  --access-key=MYACCESSKEY \
  --secret=MYSECRETKEY
```

### 4. Test S3 Access

```bash
# Using aws-cli
aws --endpoint-url=http://10.40.0.41:7480 s3 ls
aws --endpoint-url=http://10.40.0.41:7480 s3 mb s3://mybucket
```

## Variables

### Cluster Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | Ceph cluster name | `"ceph"` |
| `cluster_fsid` | Cluster UUID (auto-generated if empty) | `""` |
| `storage_pool` | Incus storage pool for containers | `"local"` |
| `image` | Container image | `"images:debian/trixie/cloud"` |

### Network Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `storage_network_name` | Storage network name | Required |
| `public_network` | Public network CIDR | Required |
| `cluster_network` | Cluster network CIDR | Same as public |

### Resource Limits

| Variable | Description | Default |
|----------|-------------|---------|
| `mon_cpu_limit` | MON CPU limit | `"2"` |
| `mon_memory_limit` | MON memory limit | `"2GB"` |
| `mgr_cpu_limit` | MGR CPU limit | `"2"` |
| `mgr_memory_limit` | MGR memory limit | `"1GB"` |
| `osd_cpu_limit` | OSD CPU limit | `"4"` |
| `osd_memory_limit` | OSD memory limit | `"4GB"` |
| `rgw_cpu_limit` | RGW CPU limit | `"2"` |
| `rgw_memory_limit` | RGW memory limit | `"2GB"` |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_fsid` | Ceph cluster FSID |
| `mon_endpoints` | List of MON endpoints |
| `mgr_prometheus_endpoints` | MGR Prometheus metrics endpoints |
| `s3_endpoints` | List of S3 API endpoints |
| `primary_s3_endpoint` | Primary S3 endpoint |

## Security Considerations

- **OSD containers run privileged** for block device access
- All containers use the dedicated storage network
- CephX authentication is enabled by default
- Keys must be manually distributed after bootstrap

## Troubleshooting

### Check daemon status

```bash
incus exec ceph-mon-node01 -- systemctl status ceph-mon@node01
incus exec ceph-mgr-node01 -- systemctl status ceph-mgr@node01
incus exec ceph-osd-node01 -- systemctl status ceph-osd@*
incus exec ceph-rgw-node01 -- systemctl status ceph-radosgw@rgw.node01
```

### Check logs

```bash
incus exec ceph-mon-node01 -- journalctl -u ceph-mon@node01
incus exec ceph-osd-node01 -- journalctl -u ceph-osd@*
```

### Cluster health

```bash
incus exec ceph-mon-node01 -- ceph health detail
incus exec ceph-mon-node01 -- ceph osd tree
incus exec ceph-mon-node01 -- ceph df
```
