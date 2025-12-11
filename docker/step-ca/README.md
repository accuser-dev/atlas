# Step-CA Docker Image

Internal ACME-enabled Certificate Authority for Atlas infrastructure.

## Overview

This image provides an internal CA using [Smallstep step-ca](https://smallstep.com/docs/step-ca/) that:
- Automatically initializes on first run
- Provides ACME endpoint for automated certificate requests
- Issues short-lived certificates (24h default)
- Persists CA state to volume

## Usage

### Basic Usage

```bash
docker run -d \
  --name step-ca \
  -p 9000:9000 \
  -v step-ca-data:/home/step \
  ghcr.io/accuser-dev/atlas/step-ca:latest
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STEPCA_NAME` | `Atlas Internal CA` | CA organization name |
| `STEPCA_DNS` | `step-ca.incus,localhost` | DNS names for CA certificate |
| `STEPCA_ADDRESS` | `:9000` | Listen address |
| `STEPCA_PROVISIONER` | `acme` | Default provisioner name |
| `STEPCA_PASSWORD` | (generated) | Password for CA keys |
| `STEPCA_CERT_DURATION` | `24h` | Default certificate duration |
| `STEPCA_ROOT_DURATION` | `87600h` | Root CA duration (10 years) |

### Volumes

Mount `/home/step` to persist:
- Root CA private key
- Intermediate CA private key
- CA configuration
- Certificate database

**Important**: Back up this volume! Loss of CA keys means all issued certificates become unverifiable.

## Requesting Certificates

Services can request certificates using the ACME protocol:

```bash
# Using step CLI
step ca certificate \
  --ca-url https://step-ca.incus:9000 \
  --root /path/to/root-ca.pem \
  --provisioner acme \
  myservice.incus \
  cert.pem key.pem

# Using certbot
certbot certonly \
  --standalone \
  --server https://step-ca.incus:9000/acme/acme/directory \
  -d myservice.incus
```

## Getting the Root CA Certificate

The root CA certificate is needed by all clients to trust issued certificates:

```bash
# From running container
docker cp step-ca:/home/step/root-ca.pem ./root-ca.pem

# Or via ACME endpoint
curl -k https://step-ca.incus:9000/roots.pem > root-ca.pem
```

## Certificate Lifecycle

| Type | Duration | Renewal |
|------|----------|---------|
| Root CA | 10 years | Manual rotation |
| Intermediate CA | 10 years | Automatic |
| Service certificates | 24 hours | Auto-renew at 16h |

## Security Considerations

1. **Protect the volume**: Contains CA private keys
2. **Network isolation**: Run on management network only
3. **Short-lived certs**: 24h limits exposure window
4. **Password management**: Use `STEPCA_PASSWORD` env var or let it auto-generate

## Troubleshooting

### Check CA health
```bash
docker exec step-ca step ca health
```

### View CA configuration
```bash
docker exec step-ca cat /home/step/config/ca.json
```

### View issued certificates
```bash
docker exec step-ca step ca certificate list
```

## References

- [step-ca Documentation](https://smallstep.com/docs/step-ca/)
- [ACME Protocol](https://smallstep.com/docs/step-ca/provisioners/#acme)
- [step CLI Reference](https://smallstep.com/docs/step-cli/)
