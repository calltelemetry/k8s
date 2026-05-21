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

Required product images are API and SPA. Optional services are enabled only when
their values set `enabled: true`. Enabling Caddy moves public ingress to the
`caddy` chart and can disable direct SPA ingress, preserving a single public
origin without conflating image slots.

## Gateway Values

Minimal Caddy gateway override:

```yaml
caddy:
  enabled: true
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
