# Credential Generator - Quick Start

## Install (30 seconds)

```bash
# 1. Create namespace
kubectl create namespace my-ns --dry-run=client -o yaml | kubectl apply -f -

# 2. Install credential-generator (auto-generates secrets)
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-ns

# 3. Wait for secrets
sleep 5 && kubectl get secrets -n my-ns
```

## Verify Secrets Created

```bash
# List secrets
kubectl get secrets -n my-ns | grep credentials

# View a secret
kubectl get secret postgres-credentials -n my-ns -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

## Use in PostgreSQL

```bash
helm install postgresql ./k8s/helm/charts/postgresql \
  -n my-ns \
  --set existingSecret=postgres-credentials
```

## Use in MinIO

```bash
helm install minio ./k8s/helm/charts/minio \
  -n my-ns \
  --set auth.existingSecret=minio-credentials
```

## Custom Credentials

```bash
# At install time
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-ns \
  --set postgres.password="MyPass123!" \
  --set minio.rootPassword="MinioPass456!"

# Via values file
helm install credential-generator ./k8s/helm/charts/credential-generator \
  -n my-ns \
  -f values-prod.yaml
```

## One-Line Deployment (Full Stack)

```bash
./k8s/deploy-with-credentials.sh my-namespace
```

## Test (Automated)

```bash
./k8s/test-credential-generator.sh
```

## Troubleshooting

**Secrets not created?**
```bash
kubectl logs -n my-ns job/test-release-credential-generator-job
```

**Check RBAC?**
```bash
kubectl describe role -n my-ns test-release-credential-generator
kubectl describe rolebinding -n my-ns test-release-credential-generator
```

**View all created secrets?**
```bash
kubectl get secret -n my-ns -o wide | grep credentials
```

## Key Points

- Pre-install hook only (doesn't run on upgrades)
- Idempotent (safe to reinstall)
- Generates 32-char secure random passwords
- All values overridable
- Least-privilege RBAC

## For Detailed Information

- See: `CREDENTIAL-GENERATOR-INTEGRATION.md` (deployment guide)
- See: `k8s/helm/charts/credential-generator/README.md` (chart docs)
- See: `CREDENTIAL-GENERATOR-SUMMARY.md` (technical details)
