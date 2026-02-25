# Credential Generator Integration Guide

This document describes how to integrate the credential-generator Helm chart with your infrastructure deployment.

## Overview

The `credential-generator` chart is a **pre-install hook** that runs on `helm install` (not `helm upgrade`) to automatically generate secure credentials for infrastructure services:
- PostgreSQL
- S3-compatible storage (SeaweedFS)
- NATS

## Architecture

```
deployment flow
└── helm install
    ├── pre-install hooks (weight: -20)
    │   ├── ServiceAccount
    │   ├── Role
    │   └── RoleBinding
    └── pre-install hooks (weight: -10)
        └── credential-generator Job
            ├── Check if secrets exist
            ├── Generate secure random passwords (32-char base64)
            └── Create secrets if missing
```

## Installation Order

When deploying your infrastructure stack, install in this order:

```bash
# 1. Create namespace (if not exists)
kubectl create namespace my-namespace --dry-run=client -o yaml | kubectl apply -f -

# 2. Install credential-generator FIRST (pre-install hook runs here)
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-namespace

# 3. Install other services (they reference secrets created above)
helm install postgresql ./k8s/helm/charts/postgresql \
  -n my-namespace

helm install seaweedfs ./k8s/helm/charts/seaweedfs \
  -n my-namespace

helm install nats ./k8s/helm/charts/nats \
  -n my-namespace
```

## Generated Secrets

The credential-generator creates three secrets:

| Secret Name | Keys | Default Values |
|------------|------|-----------------|
| `postgres-credentials` | `POSTGRES_USER`, `POSTGRES_PASSWORD` | `calltelemetry`, auto-generated |
| `s3-credentials` | `S3_ROOT_USER`, `S3_ROOT_PASSWORD` | `minioadmin`, auto-generated |
| `nats-credentials` | `NATS_USER`, `NATS_PASSWORD` | `nats`, auto-generated |

## Using Generated Credentials

### PostgreSQL

To use auto-generated PostgreSQL credentials, update your values.yaml:

```yaml
# postgresql values.yaml
existingSecret: "postgres-credentials"
```

Then the PostgreSQL cluster will use credentials from that secret.

### S3-Compatible Storage (SeaweedFS)

To use auto-generated S3 credentials, update your values.yaml:

```yaml
# seaweedfs values.yaml
auth:
  existingSecret: "s3-credentials"
```

### NATS

NATS doesn't have built-in existingSecret support in our current templates, but you can:

1. Use the secrets created by credential-generator
2. Reference them in your NATS deployment via environment variables
3. Or configure NATS with the values from the secret

## Custom Credentials

To use custom credentials instead of auto-generated ones:

```bash
# Pass custom values at install time
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-namespace \
  --set postgres.username=customuser \
  --set postgres.password=custompass \
  --set s3.rootUser=admin \
  --set s3.rootPassword=secretpass
```

Or via values file:

```yaml
# values-prod.yaml
autoGenerate:
  enabled: true

postgres:
  username: "produser"
  password: "SecurePassword123!"

s3:
  rootUser: "prodadmin"
  rootPassword: "S3Secret456!"

nats:
  username: "natsadmin"
  password: "NATSSecret789!"
```

Then:

```bash
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-namespace \
  -f values-prod.yaml
```

## Disabling Auto-Generation

If you prefer to manage credentials manually:

```bash
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-namespace \
  --set enabled=false
```

Or set `autoGenerate.enabled=false` in values.

## Verification

After installation, verify secrets were created:

```bash
# List all secrets in namespace
kubectl get secrets -n my-namespace

# Inspect a specific secret
kubectl get secret postgres-credentials -n my-namespace -o jsonpath='{.data.POSTGRES_USER}' | base64 -d
kubectl get secret postgres-credentials -n my-namespace -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

# Check Job status
kubectl get jobs -n my-namespace -l app.kubernetes.io/name=credential-generator
kubectl logs -n my-namespace job/my-release-credential-generator-job
```

## Integration with Tiltfile

For local development with Tilt, you may want to skip credential generation and use dev defaults:

```python
# Tiltfile
load('ext://helm_resource', 'helm_resource', 'helm_repo')

# Skip credential-generator in dev (use dev defaults instead)
helm_resource('credential-generator',
  'credential-generator',
  flags=[
    '--set', 'enabled=false'  # Dev uses hardcoded defaults
  ]
)

# Use dev credentials in other charts
helm_resource('postgresql',
  'postgresql',
  flags=[
    '--set', 'cluster.postgresql.username=calltelemetry',
    '--set', 'cluster.postgresql.password=calltelemetry_dev_password'
  ]
)
```

## CRITICAL: Pre-install Only

This chart **ONLY** runs on `helm install`. Upgrades will NOT regenerate credentials. This is intentional to protect existing deployments.

Flow:
```
First deployment (helm install)
  → credential-generator pre-install hook runs
  → Secrets created

Subsequent deployments (helm upgrade)
  → credential-generator pre-install hook does NOT run
  → Existing secrets preserved
```

## Troubleshooting

### Secrets not created

Check if the Job ran:

```bash
kubectl get jobs -n my-namespace
kubectl logs -n my-namespace job/my-release-credential-generator-job
```

Check RBAC:

```bash
kubectl get serviceaccount -n my-namespace
kubectl get role -n my-namespace
kubectl get rolebinding -n my-namespace
```

Check if secrets were created by other means:

```bash
kubectl get secrets -n my-namespace | grep credentials
```

### Job failed with permission error

Ensure the ServiceAccount, Role, and RoleBinding were created:

```bash
kubectl describe role -n my-namespace my-release-credential-generator
kubectl describe rolebinding -n my-namespace my-release-credential-generator
```

The Role must have permissions to `get`, `list`, and `create` secrets.

### Secrets already exist

This is expected behavior if you re-install in the same namespace. The script checks for existing secrets and skips creation.

To use existing secrets with other charts:

```bash
# Update postgresql to use existing secret
helm upgrade postgresql ./k8s/helm/charts/postgresql \
  -n my-namespace \
  --set existingSecret=postgres-credentials

# Update seaweedfs to use existing secret
helm upgrade seaweedfs ./k8s/helm/charts/seaweedfs \
  -n my-namespace \
  --set auth.existingSecret=s3-credentials
```

### Password doesn't match what I set

Ensure you:
1. Set values at install time (not in default values.yaml)
2. Specify the correct secret name in dependent charts
3. Restart dependent pods after credential generation

Example:

```bash
# Install credential-generator with custom password
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-namespace \
  --set postgres.password="MySecurePass123!"

# Install PostgreSQL with existing secret
helm install postgresql ./k8s/helm/charts/postgresql \
  -n my-namespace \
  --set existingSecret=postgres-credentials
```

## Production Checklist

- [ ] Generate strong credentials (32+ chars recommended)
- [ ] Use `--set` flags or separate values files (don't commit credentials)
- [ ] Enable Kubernetes secret encryption at rest (SEAlED Secrets, Vault, etc.)
- [ ] Store credentials in a secret management system (Vault, AWS Secrets Manager, etc.)
- [ ] Audit secret access: `kubectl get events -n my-namespace`
- [ ] Rotate credentials periodically
- [ ] Document credential rotation procedures

## See Also

- [credential-generator README](./helm/charts/credential-generator/README.md)
- [PostgreSQL Helm Chart](./helm/charts/postgresql/README.md)
- [SeaweedFS Helm Chart](./helm/charts/seaweedfs/README.md)
- [NATS Helm Chart](./helm/charts/nats/README.md)
