# CallTelemetry Helmfile Deployment

Helmfile deploys the entire CallTelemetry stack in the correct order with a single command. Supports on-prem (K3s), DigitalOcean, AWS EKS, and Azure AKS.

## Prerequisites

- Kubernetes cluster (v1.30+)
- Helm v3+ (Helm v4 SSA compatibility handled automatically)
- Helmfile v1+
- `kubectl` configured to communicate with your cluster

## Installation

### Install Required Tools

1. Install Helmfile:

```bash
# macOS
brew install helmfile

# Linux
curl -L https://github.com/helmfile/helmfile/releases/latest/download/helmfile_linux_amd64 > /usr/local/bin/helmfile
chmod +x /usr/local/bin/helmfile
```

2. Install the Helm Diff Plugin:

```bash
helm plugin install https://github.com/databus23/helm-diff
```

## Repository Setup

```bash
git clone https://github.com/calltelemetry/k8s.git
cd k8s
```

## Usage

The helmfile deploys the entire CallTelemetry environment. It supports multiple environments with separate configuration files:

- `ct-dev` — Development (uses `env-common.yaml` + `env-dev.yaml`)
- `ct-prod` — Production (uses `env-common.yaml` + `env-prod.yaml`)

### Deploy

```bash
# Dev environment (recommended: apply shows diff first)
helmfile --environment ct-dev apply

# Prod environment
helmfile --environment ct-prod apply

# Without diff
helmfile --environment ct-dev sync
```

### Preview

```bash
# Render all manifests without deploying
helmfile --environment ct-dev template > /tmp/rendered.yaml
```

### Teardown

```bash
helmfile --environment ct-dev destroy
```

## What Gets Deployed

Helmfile installs these releases in dependency order:

| Release | Namespace | Condition | Description |
|---------|-----------|-----------|-------------|
| `metallb` | metallb-system | On-prem only | L2 load balancer for bare metal |
| `cnpg` | cnpg-system | CNPG database only | CloudNativePG operator |
| `postgresql` | app namespace | CNPG database only | PostgreSQL cluster |
| `haproxy-ingress` | app namespace | Always | HAProxy ingress controller |
| `ingress-haproxy` | app namespace | Always | Load balancers + routing |
| `nats` | app namespace | Always | NATS JetStream messaging |
| `api` | app namespace | Always | CallTelemetry API |
| `ct-web` | app namespace | Always | Vue frontend |
| `traceroute` | app namespace | Always | Traceroute service |

## Platform Differences

| | On-Prem (K3s) | DigitalOcean | AWS EKS | Azure AKS |
|---|---|---|---|---|
| **MetalLB** | Installed | Not needed | Not needed | Not needed |
| **LB type** | Static IPs via L2 | DO Load Balancer | AWS NLB | Azure LB |
| **Storage** | `local-path` | `do-block-storage` | `gp3` | `managed-csi` |

For cloud platforms, skip MetalLB and override the storage class in your values files. The ingress chart's `advertiseL2MetalLb: false` disables MetalLB resource creation — LoadBalancer services get cloud-provisioned IPs automatically.

## Database Options

| | CloudNativePG (Modern) | Crunchy PGO (Legacy) |
|---|---|---|
| **Operator** | Installed by helmfile | Pre-installed externally |
| **DB Cluster** | CNPG Cluster CR deployed | Managed by PGO in `postgres-operator` ns |
| **Secret** | Auto-created by CNPG | Manually copied to app namespace |

For Crunchy PGO, skip the `cnpg` and `postgresql` releases and configure the API chart to point at your existing PGO database secret.

## Customization

### Environment Files

- `env-common.yaml` — Shared config (chart repos, versions)
- `env-dev.yaml` — Dev-specific settings (values file paths, replicas)
- `env-prod.yaml` — Prod-specific settings

Each environment file points to values files in the `examples/` directory. To customize:
1. Copy the relevant example values file
2. Edit your copy
3. Update the environment file to point to your copy

### Cloud Storage Classes

Override storage in your postgresql and API values files:

```yaml
# postgresql values (CNPG)
cluster:
  storage:
    storageClass: do-block-storage  # or gp3, managed-csi

# API values (log PVCs)
logs:
  storageClassName: do-block-storage
```

## Helm v4 Compatibility

Helmfile sets `--server-side=false` globally. Helm v4 defaults to Server-Side Apply (SSA) which tracks field ownership per manager. This conflicts with controllers that mutate their own resources (MetalLB webhook certs, CNPG status fields). Disabling SSA avoids field manager conflicts on upgrade.

The CNPG release uses `wait: true` and `waitForJobs: true` to ensure the webhook is registered before PostgreSQL Cluster CRs are applied.

## Troubleshooting

### General

```bash
helmfile --environment ct-dev status
kubectl get pods -n ct-dev
kubectl get svc -n ct-dev
```

### Database Issues

```bash
# CNPG cluster status
kubectl get cluster -n ct-dev

# PGO: verify secret was copied
kubectl get secret hippo-pguser-calltelemetry -n ct-dev

# API DB connection logs
kubectl logs -n ct-dev -l app=api --tail=50
```

### Load Balancer Issues

```bash
# On-prem: MetalLB speaker logs
kubectl logs -n metallb-system -l app=metallb -l component=speaker

# Cloud: check external IP assignment
kubectl get svc -n ct-dev -o wide

# HAProxy logs
kubectl logs -n ct-dev -l app.kubernetes.io/name=haproxy-ingress
```

### Helm v4 Field Manager Conflicts

If `helm upgrade` fails with field ownership errors, verify `--server-side=false` is set in helmDefaults or passed as a CLI flag.
