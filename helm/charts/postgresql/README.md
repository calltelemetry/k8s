# PostgreSQL Helm Chart

PostgreSQL database using CloudNativePG operator with CallTelemetry extensions (pg_ivm, TimescaleDB).

## Prerequisites

- Kubernetes 1.25+
- CloudNativePG operator installed in the cluster
- Helm 3.x

## Installing the CloudNativePG Operator

Before deploying this chart, install the CloudNativePG operator:

```bash
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace
```

Or via helmfile (recommended):

```yaml
repositories:
  - name: cnpg
    url: https://cloudnative-pg.github.io/charts

releases:
  - name: cnpg
    namespace: cnpg-system
    createNamespace: true
    chart: cnpg/cloudnative-pg
    version: 0.23.0
```

## Installing the Chart

### Development (single instance, no backups)

```bash
helm install postgresql ./postgresql -n calltelemetry
```

### Production (HA with 3 instances, S3 backups)

```bash
helm install postgresql ./postgresql -n calltelemetry \
  -f values.yaml \
  -f values-production.yaml \
  --set existingSecret=my-pg-credentials \
  --set backup.s3.existingSecret=my-s3-credentials
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | PostgreSQL image | `calltelemetry/postgres` |
| `image.tag` | Image tag | `17` |
| `cluster.instances` | Number of instances | `1` |
| `cluster.postgresql.database` | Database name | `calltelemetry` |
| `cluster.postgresql.username` | Database user | `calltelemetry` |
| `cluster.postgresql.password` | Database password | `calltelemetry_dev_password` |
| `cluster.storage.size` | PVC size | `5Gi` |
| `backup.enabled` | Enable S3 backups | `false` |
| `pooler.enabled` | Enable PgBouncer pooler | `false` |

See `values.yaml` for all configuration options.

## Connecting to PostgreSQL

CloudNativePG creates three services automatically:

| Service | Description |
|---------|-------------|
| `<release>-postgresql-rw` | Read-write (primary) |
| `<release>-postgresql-ro` | Read-only (replicas) |
| `<release>-postgresql-r` | Any instance |

Example connection string:
```
postgresql://calltelemetry:password@postgresql-rw.namespace.svc.cluster.local:5432/calltelemetry
```

## Extensions

The CallTelemetry PostgreSQL image includes:

- **pg_ivm** - Incremental View Maintenance
- **TimescaleDB** - Time-series database extension

These are automatically enabled via `postInitSQL` during bootstrap.

## Scaling

To scale from dev to prod, simply change `instances`:

```yaml
cluster:
  instances: 3  # HA mode
```

CloudNativePG handles:
- Automatic failover
- Streaming replication
- Read replica load balancing

## Backups

When `backup.enabled: true`, the chart configures:

- Continuous WAL archiving to S3
- Scheduled full backups (daily by default)
- Point-in-Time Recovery (PITR) capability

Create the S3 credentials secret:

```bash
kubectl create secret generic postgresql-s3-credentials \
  --from-literal=ACCESS_KEY_ID=your-access-key \
  --from-literal=ACCESS_SECRET_KEY=your-secret-key \
  -n calltelemetry
```
