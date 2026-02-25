# SeaweedFS Helm Chart

SeaweedFS S3-compatible object storage for CallTelemetry audio files and JTAPI JAR storage.

This chart deploys SeaweedFS in combined server mode with S3 API support, serving as the S3-compatible storage backend for CallTelemetry.

## Features

- SeaweedFS in combined server mode (Master + Filer + S3)
- S3 API compatible with AWS CLI and SDK
- Persistent storage via PVC
- Automatic bucket initialization via Helm hooks or as standalone Job
- S3 configuration via ConfigMap (s3.json)
- Health checks on cluster health endpoint
- Resource requests and limits configured
- Support for existing secrets for credentials

## Quick Start

### Default Installation

```bash
helm install seaweedfs ./seaweedfs
```

This deploys SeaweedFS with:
- Default credentials: `minioadmin` / `minioadmin`
- 5Gi persistent storage
- Single replica
- Automatic bucket creation (ct-audio)

### Custom Values

```bash
helm install seaweedfs ./seaweedfs \
  --set auth.accessKey=myaccesskey \
  --set auth.secretKey=mysecretkey \
  --set persistence.size=10Gi
```

## Architecture

### Service Endpoints

The SeaweedFS service exposes three ports:

- **S3 (port 8333)**: S3 API endpoint for bucket operations
- **Filer (port 8888)**: Filer HTTP interface for file management
- **Master (port 9333)**: Master server with cluster health endpoint

### Storage

- Data stored in `/data` directory
- Persistent storage via PVC (default 5Gi)
- Can use existing PVC via `persistence.existingClaim`

### Configuration

- S3 credentials defined in `auth` section
- S3 configuration file (s3.json) generated from ConfigMap
- Admin identity with full permissions (Admin, Read, Write, List, Tagging)

### Bucket Initialization

The chart includes an init Job that:
1. Waits for SeaweedFS S3 to be ready
2. Creates buckets defined in `values.buckets`
3. Lists created buckets for verification

Uses AWS CLI for bucket operations (S3 compatible).

## Configuration

See `values.yaml` for all available options:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `chrislusf/seaweedfs` |
| `image.tag` | Container image tag | `latest` |
| `auth.accessKey` | S3 access key ID | `minioadmin` |
| `auth.secretKey` | S3 secret access key | `minioadmin` |
| `auth.existingSecret` | Use existing Secret for credentials | `""` |
| `service.s3Port` | S3 API port | `8333` |
| `service.filerPort` | Filer port | `8888` |
| `service.masterPort` | Master port | `9333` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC size | `5Gi` |
| `persistence.storageClass` | Storage class name | `""` (cluster default) |
| `persistence.existingClaim` | Use existing PVC | `""` |
| `bucketInit.enabled` | Enable bucket initialization Job | `true` |
| `bucketInit.useHelmHooks` | Use Helm hooks for init Job | `true` |
| `masterVolumeSizeLimitMB` | Master volume size limit | `100` |
| `healthCheck.liveness.initialDelaySeconds` | Liveness probe initial delay | `10` |
| `healthCheck.readiness.initialDelaySeconds` | Readiness probe initial delay | `10` |

## Using with Existing Credentials

If you already have S3 credentials in a secret:

```bash
kubectl create secret generic my-s3-credentials \
  --from-literal=S3_ACCESS_KEY_ID=mykey \
  --from-literal=S3_SECRET_ACCESS_KEY=mysecret

helm install seaweedfs ./seaweedfs \
  --set auth.existingSecret=my-s3-credentials
```

## Accessing SeaweedFS

### From within the cluster

```bash
# S3 endpoint
aws --endpoint-url http://seaweedfs:8333 s3 ls

# Using environment variables
export AWS_ACCESS_KEY_ID=minioadmin
export AWS_SECRET_ACCESS_KEY=minioadmin
aws --endpoint-url http://seaweedfs:8333 s3 ls
```

### Using kubectl port-forward

```bash
kubectl port-forward svc/seaweedfs 8333:8333
aws --endpoint-url http://localhost:8333 s3 ls
```

### From pods via OrbStack DNS

```bash
aws --endpoint-url http://seaweedfs.{namespace}.svc.cluster.local:8333 s3 ls
```

## Troubleshooting

### Check pod status

```bash
kubectl get pods -l app=seaweedfs
kubectl describe pod <seaweedfs-pod-name>
```

### View logs

```bash
kubectl logs -l app=seaweedfs
```

### Check S3 endpoint

```bash
kubectl exec -it <seaweedfs-pod-name> -- curl http://localhost:9333/cluster/healthz
```

### Verify buckets were created

```bash
kubectl logs -l app.kubernetes.io/component=bucket-init
```

## Migration Reference (from MinIO)

This chart replaced the previous MinIO chart. Key differences for reference:

| Feature | MinIO | SeaweedFS |
|---------|-------|-----------|
| Binary | `minio/minio` | `chrislusf/seaweedfs` |
| Command | `server /data` | `weed server -s3` |
| API Port | 9000 | 8333 |
| Console Port | 9001 | None (Filer at 8888) |
| Config Method | Environment variables | s3.json ConfigMap |
| Bucket Init | minio/mc | amazon/aws-cli |

Both are S3-compatible and work with AWS CLI/SDK.

## Notes

- The S3 configuration is immutable in this chart - modify via ConfigMap if needed
- Default credentials should be changed in production
- Volume size limit is set to 100MB for the master - adjust `masterVolumeSizeLimitMB` as needed
- Health checks use the master cluster health endpoint
- Chart uses Helm hooks for bucket initialization - set `bucketInit.useHelmHooks=false` for Tilt deployments that don't support hooks
