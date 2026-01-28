# Credential Generator Helm Chart

Automatically generates secure credentials for infrastructure services (PostgreSQL, MinIO, NATS) on **new deployments only**.

## Features

- **Pre-install hook only** — Runs on `helm install`, not `helm upgrade`, so existing installations are never affected
- **Idempotent** — If secrets already exist, skips creation (safe to run multiple times)
- **Secure random generation** — Uses `openssl rand -base64 32` for passwords
- **User-overridable** — All credentials can be customized via `values.yaml`
- **Least-privilege RBAC** — ServiceAccount scoped to namespace, Role limited to `get`, `list`, `create` on secrets only

## Services Covered

| Service | Secret Name | Keys |
|---------|-------------|------|
| PostgreSQL | `postgres-credentials` | `POSTGRES_USER`, `POSTGRES_PASSWORD` |
| MinIO | `minio-credentials` | `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` |
| NATS | `nats-credentials` | `NATS_USER`, `NATS_PASSWORD` |

## Installation

### Prerequisites
- Kubernetes 1.19+
- Helm 3.0+

### Install with defaults (auto-generate all credentials)
```bash
helm install credential-generator ./credential-generator \
  -n my-namespace \
  --create-namespace
```

### Install with custom credentials
```bash
helm install credential-generator ./credential-generator \
  -n my-namespace \
  --create-namespace \
  --set postgres.username=myuser \
  --set postgres.password=mypassword \
  --set minio.rootUser=admin \
  --set minio.rootPassword=secure-pass \
  --set nats.username=natsuser \
  --set nats.password=natspass
```

### Install with values file
```bash
helm install credential-generator ./credential-generator \
  -n my-namespace \
  --create-namespace \
  -f values-prod.yaml
```

## How It Works

1. **Pre-install hook** (`helm.sh/hook: pre-install`) ensures the Job only runs on `helm install`, not `helm upgrade`
2. **ServiceAccount + RBAC** allows the Job to create secrets in the namespace
3. **Idempotent script** checks if each secret exists before creating it
4. **Secure random generation** creates 32-character base64-encoded passwords if values are empty
5. **Job cleanup** via `helm.sh/hook-delete-policy: hook-succeeded,before-hook-creation` removes the Job after success

## Values Configuration

```yaml
# Enable/disable the credential generator
enabled: true

# Docker image for the Job
image:
  repository: bitnami/kubectl
  tag: latest
  pullPolicy: IfNotPresent

# Auto-generate mode
autoGenerate:
  enabled: true

# PostgreSQL credentials (leave empty to auto-generate)
postgres:
  username: ""              # Default: calltelemetry
  password: ""              # Default: 32-char secure random
  secretName: "postgres-credentials"

# MinIO credentials (leave empty to auto-generate)
minio:
  rootUser: ""              # Default: minioadmin
  rootPassword: ""          # Default: 32-char secure random
  secretName: "minio-credentials"

# NATS credentials (leave empty to auto-generate)
nats:
  username: ""              # Default: nats
  password: ""              # Default: 32-char secure random
  secretName: "nats-credentials"
```

## Disabling Credential Generation

To skip credential generation entirely:

```bash
helm install credential-generator ./credential-generator \
  --set enabled=false
```

Or:

```bash
helm install credential-generator ./credential-generator \
  --set autoGenerate.enabled=false
```

## Verification

After installation, verify secrets were created:

```bash
kubectl get secrets -n my-namespace
kubectl get secret postgres-credentials -n my-namespace -o yaml
```

## Updating Credentials

To update credentials **after initial deployment**, use `kubectl`:

```bash
kubectl create secret generic postgres-credentials \
  --from-literal=POSTGRES_USER=newuser \
  --from-literal=POSTGRES_PASSWORD=newpassword \
  --dry-run=client -o yaml | kubectl apply -f -
```

Then restart the affected services:

```bash
kubectl rollout restart deployment/postgresql -n my-namespace
```

## CRITICAL: Pre-install Only

This chart **ONLY** runs on `helm install`. To ensure it doesn't run on upgrades:

**Do NOT use this chart for upgrades.** Only use for initial deployments:

```bash
# First deployment (credential-generator runs)
helm install calltelemetry ./calltelemetry \
  -n my-namespace \
  --create-namespace

# Subsequent upgrades (credential-generator does NOT run)
helm upgrade calltelemetry ./calltelemetry \
  -n my-namespace
```

## Troubleshooting

### Secrets not created
1. Check if the Job ran: `kubectl get jobs -n my-namespace -l app.kubernetes.io/name=credential-generator`
2. Check Job logs: `kubectl logs -n my-namespace job/credential-generator-credential-generator-job`
3. Check for RBAC errors: `kubectl describe role credential-generator -n my-namespace`

### Already exists error
This is expected if you install/reinstall in the same namespace. Secrets are idempotent—if they already exist, the Job skips them.

### Password not secure enough
Override with custom password:
```bash
--set postgres.password=$(openssl rand -base64 32)
```

## Testing

To test the credential generator in isolation:

```bash
# Create a test namespace
kubectl create namespace test-creds

# Install just the credential-generator
helm install test-creds ./credential-generator -n test-creds

# Verify secrets were created
kubectl get secrets -n test-creds

# Clean up
kubectl delete namespace test-creds
```

## Security Considerations

- Credentials are stored as Kubernetes Secrets (base64-encoded, not encrypted by default)
- **Recommended:** Enable Kubernetes secret encryption at rest (SEAlED Secrets, Vault, etc.)
- **Do NOT** commit secrets to Git; use values files only for non-production defaults
- **Do NOT** use weak passwords in production; override with strong credentials

## License

Copyright CallTelemetry LLC. All rights reserved.
