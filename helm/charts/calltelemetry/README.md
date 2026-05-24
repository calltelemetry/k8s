# CallTelemetry Stack Chart

`calltelemetry` is the standard deployable product stack chart. Staging,
release, customer, and preview environments should layer values onto this chart
instead of maintaining environment-specific chart forks.

## Image Ownership

Each component owns its own image value block:

| Component | Values key | Purpose |
| --- | --- | --- |
| API/Admin | `api.api.image`, `api.admin.image` | Phoenix API and admin worker images |
| SPA | `vue-web.image` | Quasar/Vue static app image |
| Gateway | `caddy.image` | Caddy reverse-proxy image only |
| JTAPI sidecar | `jtapi-sidecar.image` | JTAPI sidecar service |
| JTAPI operator | `jtapi-operator.image` | Kubernetes JTAPI operator |
| Media | `ct-media.image` | Media service |
| Syslog | `syslog.image` | Syslog ingest service |
| Traceroute | `traceroute.image` | Traceroute service |

Do not put the SPA image in `caddy.image`. The gateway chart only runs Caddy
and routes traffic to the SPA and API services.

## Environment Override Pattern

Every deployment should render or maintain a values file that sets the component
images, routes, ingress, secrets, and enabled optional services for that
environment. PR previews generate those values from a lockfile, but the chart
does not require or assume a preview-only values schema.

```bash
helm dependency build k8s/helm/charts/calltelemetry
helm upgrade --install ct-pr-123 k8s/helm/charts/calltelemetry \
  --namespace ct-pr-123 \
  --values .ct-preview/ct-pr-123/values/stack.yaml
```

Required product images are API, SPA, and Caddy. Optional backend services are
enabled only when their values set `enabled: true`. Public ingress should live
on the `caddy` chart; direct SPA ingress is a legacy fallback, not the standard
stack contract.

Resource sizing is also an environment override. The API chart exposes
`api.api.resources` and `api.admin.resources`; previews should size the admin
pod for release startup work such as migrations and partition checks instead
of patching Kubernetes resources after Helm renders the chart.

## Required, Optional, And Shared Components

The stack has three component classes:

| Class | Components | Deployment rule |
| --- | --- | --- |
| Required product shell | API/Admin, SPA, Caddy gateway | Always rendered by the stack chart |
| Optional workloads | JTAPI sidecar, JTAPI operator, media, syslog, traceroute | Rendered only when `<service>.enabled: true` |
| Shared platform services | Postgres, NATS, OTel collector, Prometheus, Grafana | Deployed outside each product release and referenced by values |

Optional workloads use the same override pattern:

```yaml
<service>:
  enabled: true
  replicaCount: 1
  image:
    repository: registry.depot.dev/<project-id>
    tag: <service>-<sha>
    pullPolicy: Always
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

Service-specific settings stay under the same key. For example, syslog owns its
UDP/TCP service exposure, JTAPI owns its websocket and NATS settings, and media
owns its gRPC service and object-storage settings.

OTel is configured as instrumentation for each workload, not as a per-release
observability stack. Environment values should point enabled workloads at a
shared collector, for example:

```yaml
jtapi-sidecar:
  enabled: true
  otel:
    enabled: true
    endpoint: http://otel-collector.preview-observability.svc.cluster.local:4318/v1/traces

ct-media:
  enabled: true
  otel:
    enabled: true
    endpoint: http://otel-collector.preview-observability.svc.cluster.local:4317

syslog:
  enabled: true
  otel:
    enabled: true
    endpoint: http://otel-collector.preview-observability.svc.cluster.local:4318
```

Do not add per-PR Prometheus, Grafana, or OTel collector releases to this chart.
Those belong to the cluster/platform layer.

## Gateway Values

Minimal Caddy gateway override:

```yaml
caddy:
  image:
    repository: registry.depot.dev/zlcvc29kp9
    tag: caddy-builder-<sha>
    pullPolicy: Always
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - host: ct-pr-123.preview.do.calltelemetry.com
        paths:
          - /
  routes:
    api:
      service: admin-internal-service
      port: 4000
    spa:
      service: ct-web-service
      port: 8080
```
