# Production observability

The production observability releases are managed by `helmfile.yaml` in the
`observability` namespace. They are enabled only for the `ct-prod` Helmfile
environment and do not alter the separate `ci-analytics` installation.

## Required out-of-band Secrets

Create these Secrets through the deployment secret manager before syncing the
production Helmfile. Never put their values in a values file or ConfigMap.

### Dashboard runtime Secret

Namespace: `dashboard`
Name: `dashboard-runtime`

Core and database keys:

- `secret_key_base`
- `jwt_secret`
- `cdr_cisco_license_secret`
- `feedback_secret_key`
- `productlane_signing_secret`
- `health_check_token`
- `db_user`
- `db_password`

### Dashboard integrations Secret

Namespace: `dashboard`
Name: `dashboard-integrations`

Required integration keys:

- `mailgun_api`
- `webex_teams_token`
- `smtp_user`
- `smtp_password`

Rotate credentials that were previously present in the production values file
before creating this Secret.

### Alertmanager Mailgun Secret

Namespace: `observability`
Name: `alertmanager-mailgun`
Key: `smtp_password`

The SMTP host, sender, username, and port are non-secret chart configuration;
the Mailgun SMTP password is mounted as a file and is never placed in the
Alertmanager ConfigMap.

### Grafana administrator Secret

Namespace: `observability`
Name: `grafana-admin`

Required keys are `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD`.
Grafana remains behind the existing authenticated access proxy.

## Deployment

Verify the dashboard-recovery node pool has at least two Ready nodes before
deploying the two-replica dashboard values. Then render and sync:

```bash
helmfile --environment ct-prod template > /tmp/ct-prod-rendered.yaml
helmfile --environment ct-prod sync
```

The independent DigitalOcean Uptime check should target:

```text
https://dash.calltelemetry.com/health/ready
```

Prometheus and Alertmanager are private ClusterIP services. Grafana is
reachable only through the existing authenticated route or an administrative
port-forward.

## Verification

```bash
kubectl -n observability get pods,svc,pvc
kubectl -n observability port-forward svc/prometheus 9090:9090
kubectl -n observability port-forward svc/alertmanager 9093:9093
kubectl -n dashboard get deploy,pods,svc,pdb
```

Confirm the Prometheus targets for `dashboard`, `kube-state-metrics`,
`node-exporter`, and `dashboard-public` are healthy. Use a synthetic alert to
verify both firing and resolved Mailgun notifications before relying on the
stack for production incident response.

The legacy unmanaged `kube-system/kube-state-metrics` installation was retired
after the managed `observability/kube-state-metrics` replacement was verified
healthy and confirmed as the only Prometheus target. Do not recreate the legacy
deployment or its ClusterRole; the Helm-managed observability release owns the
cluster-state metrics path.

This stack is now in continuous operations. Track dashboard pod memory,
restarts, OOMKilled events, scrape health, active alerts, Alertmanager email
failures, and node pressure as part of normal incident response; tune thresholds
when production behavior or alert quality requires it.
