# Caddy Gateway Chart

This chart deploys the dedicated Caddy edge gateway for CallTelemetry. It is
the standard public entrypoint for release, staging, customer, and preview
stacks that need one public origin for API, LiveView/socket paths, health
checks, and SPA fallback.

The chart owns only the Caddy gateway image:

```yaml
caddy:
  image:
    repository: calltelemetry/caddy
    tag: "2.11.3"
```

The SPA image belongs in the `vue-web` chart. The gateway routes SPA traffic to
the configured SPA service and does not serve or replace the SPA image itself.

Important values:

| Value | Default | Purpose |
| --- | --- | --- |
| `image.repository` / `image.tag` | `caddy` / `2.11.3-alpine` | Caddy image ref |
| `ingress.enabled` | `false` | Expose gateway through the cluster ingress controller |
| `routes.api.service` | `admin-internal-service` | API upstream service |
| `routes.spa.service` | `ct-vue` | SPA upstream service |
| `caddy.metrics.enabled` | `true` | Enables Caddy admin metrics on port 2019 |
