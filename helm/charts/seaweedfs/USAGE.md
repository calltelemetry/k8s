# SeaweedFS Helm Chart - Usage Examples

## Installation

### Basic Installation (Development)

```bash
cd k8s/helm/charts
helm install seaweedfs seaweedfs
```

This uses default values:
- Default credentials: minioadmin/minioadmin
- Storage: 5Gi PVC
- S3 endpoint: seaweedfs:8333
- Automatically creates ct-audio bucket

### Installation with Custom Values

```bash
helm install seaweedfs seaweedfs \
  --set auth.accessKey=mykey \
  --set auth.secretKey=mysecret \
  --set persistence.size=10Gi
```

### Using Existing Secret

If credentials are already in a secret:

```bash
kubectl create secret generic my-s3-creds \
  --from-literal=S3_ACCESS_KEY_ID=key123 \
  --from-literal=S3_SECRET_ACCESS_KEY=secret456

helm install seaweedfs seaweedfs \
  --set auth.existingSecret=my-s3-creds
```

## Integration with Tiltfile

Update your Tiltfile to use SeaweedFS:

```python
# SeaweedFS chart deployment
k8s_yaml(helm(
  './k8s/helm/charts/seaweedfs',
  namespace=namespace,
  values=['./k8s/helm/charts/seaweedfs/values.yaml']
))

# Set environment variables for services using S3
os.environ['S3_ENDPOINT'] = 'http://seaweedfs:8333'
os.environ['S3_ACCESS_KEY_ID'] = 'minioadmin'
os.environ['S3_SECRET_ACCESS_KEY'] = 'minioadmin'
```

## Accessing SeaweedFS

### From Within Cluster (via Service Name)

```bash
# List buckets
aws --endpoint-url http://seaweedfs:8333 s3 ls

# Upload file
aws --endpoint-url http://seaweedfs:8333 s3 cp file.txt s3://ct-audio/

# Download file
aws --endpoint-url http://seaweedfs:8333 s3 cp s3://ct-audio/file.txt ./
```

### From Within Cluster (via DNS)

```bash
# For namespace ct-conductor-<branch>
aws --endpoint-url http://seaweedfs.ct-conductor-sync-release-rc206.svc.cluster.local:8333 s3 ls
```

### From Local Machine (via Port Forward)

```bash
# In one terminal
kubectl port-forward svc/seaweedfs 8333:8333

# In another terminal
aws --endpoint-url http://localhost:8333 s3 ls
```

## Configuration Examples

### Create Additional Buckets

Edit values.yaml:

```yaml
buckets:
  - name: ct-audio
  - name: ct-greetings
  - name: ct-recordings
```

Then upgrade:

```bash
helm upgrade seaweedfs seaweedfs -f values.yaml
```

### Change Storage Size

```bash
helm upgrade seaweedfs seaweedfs \
  --set persistence.size=20Gi
```

### Use Specific Storage Class

```bash
helm upgrade seaweedfs seaweedfs \
  --set persistence.storageClass=my-storage-class
```

### Disable Bucket Initialization

For environments that don't support Helm hooks (like some Tilt setups):

```bash
helm install seaweedfs seaweedfs \
  --set bucketInit.useHelmHooks=false
```

Then manually create buckets:

```bash
kubectl exec -it <seaweedfs-pod> -- \
  aws --endpoint-url http://localhost:8333 s3 mb s3://ct-audio
```

## Monitoring & Troubleshooting

### Check Pod Status

```bash
kubectl get pods -l app=seaweedfs
kubectl describe pod <seaweedfs-pod-name>
```

### View Logs

```bash
# Main SeaweedFS logs
kubectl logs -l app=seaweedfs

# Bucket initialization logs
kubectl logs -l app.kubernetes.io/component=bucket-init
```

### Health Check

```bash
# Check cluster health
kubectl exec -it <seaweedfs-pod> -- \
  curl http://localhost:9333/cluster/healthz

# Should return HTTP 200 with cluster status
```

### Verify S3 Endpoint

```bash
# Port-forward to test
kubectl port-forward svc/seaweedfs 8333:8333 &
aws --endpoint-url http://localhost:8333 s3 ls
```

### Check Configuration

```bash
# View generated s3.json
kubectl get configmap seaweedfs-s3-config -o yaml

# View credentials secret
kubectl get secret seaweedfs-credentials -o yaml
```

## Environment Variables for Applications

Applications using SeaweedFS can reference these environment variables:

```bash
# Set in your deployment/pod
S3_ENDPOINT: http://seaweedfs:8333
S3_REGION: us-east-1
S3_ACCESS_KEY_ID: minioadmin
S3_SECRET_ACCESS_KEY: minioadmin
S3_BUCKET: ct-audio
S3_ENABLED: "true"

# Or reference secret directly
env:
  - name: S3_ENDPOINT
    value: "http://seaweedfs:8333"
  - name: S3_REGION
    value: "us-east-1"
  - name: S3_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: seaweedfs-credentials
        key: S3_ACCESS_KEY_ID
  - name: S3_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: seaweedfs-credentials
        key: S3_SECRET_ACCESS_KEY
```

## Upgrade & Cleanup

### Upgrade Chart

```bash
helm upgrade seaweedfs seaweedfs
```

### Delete Chart

```bash
helm uninstall seaweedfs
```

Note: This does not delete the PVC by default. To remove persistent data:

```bash
kubectl delete pvc seaweedfs-data
```

## Migration Reference (from MinIO)

| Operation | MinIO | SeaweedFS |
|-----------|-------|-----------|
| Install | `helm install minio ./minio` | `helm install seaweedfs ./seaweedfs` |
| S3 Endpoint | `minio:9000` | `seaweedfs:8333` |
| Console Access | `minio:9001` (Web UI) | `seaweedfs:8888` (Filer) |
| Config Method | Environment variables | s3.json ConfigMap |
| Bucket Init Tool | minio/mc | amazon/aws-cli |
| Health Path | `/minio/health/live` | `/cluster/healthz` |
| API Compatibility | S3 API | S3 API (compatible) |

Both are fully S3-compatible and interchangeable for basic operations.
