# Call Telemetry Kubernetes Charts

Kubernetes Helm charts for deploying CallTelemetry on any Kubernetes platform — on-prem (K3s/bare metal), DigitalOcean, AWS EKS, or Azure AKS.

## Repository Structure

```
.
├── helm/
│   ├── charts/
│   │   ├── api/             # API service chart
│   │   ├── credential-generator/ # Auto-generates secrets
│   │   ├── ingress/         # Ingress + load balancers
│   │   ├── nats/            # NATS messaging
│   │   ├── postgresql/      # CloudNativePG PostgreSQL cluster
│   │   ├── traceroute/      # Traceroute service chart
│   │   ├── teams-auth/      # Teams authentication chart
│   │   └── vue-web/         # Vue web frontend chart
├── examples/                # Reference values files per environment
├── docs/                    # Installation guides
├── helmfile.yaml            # Helmfile for one-command deployment
├── tests/                   # Unit and integration tests
└── index.yaml               # Helm repository index (GitHub Pages)
```

## Supported Platforms

| Platform | Load Balancer | Storage Class | Notes |
|----------|--------------|---------------|-------|
| **On-prem / K3s** | MetalLB L2 (static IPs) | `local-path` (K3s default) | Bare metal, single or multi-node |
| **DigitalOcean (DOKS)** | DO Load Balancer | `do-block-storage` | Managed K8s |
| **AWS EKS** | AWS NLB | `gp3` (EBS CSI) | Managed K8s |
| **Azure AKS** | Azure Load Balancer | `managed-csi` | Managed K8s |

## Architecture

1. **Load Balancers** — Route external traffic into the cluster
   - On-prem: MetalLB L2 with static IP assignments
   - Cloud: Native cloud load balancers with dynamic IPs
2. **HAProxy Ingress Controller** — Per-namespace ingress with TCP services (SFTP, Syslog)
3. **NATS Server** — JetStream messaging for inter-service communication
4. **PostgreSQL Database** — Two options:
   - **CloudNativePG (CNPG)** — Modern operator, recommended for new installs
   - **Crunchy PGO** — Legacy operator for existing Crunchy environments
5. **Call Telemetry API** — Core application (Elixir/Phoenix)
6. **Vue Web Frontend** — User interface (Vue 3/Quasar)
7. **Traceroute Service** — Network diagnostics

For architecture diagrams, see:
- [Architecture Diagram](architecture-diagram.md)
- [Detailed Architecture Diagram](detailed-architecture-diagram.md)
- [Kubernetes Resources Diagram](kubernetes-resources-diagram.md)

## Quick Start

### Option 1: Helmfile (Recommended)

Helmfile orchestrates all charts in the correct order with a single command.

```bash
git clone https://github.com/calltelemetry/k8s.git
cd k8s

# Deploy dev environment
helmfile --environment ct-dev apply

# Deploy prod environment
helmfile --environment ct-prod apply
```

See [Helmfile README](helmfile-readme.md) for full details.

### Option 2: Individual Helm Installs

Install charts one at a time from the published Helm repository:

```bash
helm repo add calltelemetry https://calltelemetry.github.io/k8s/helm/charts
helm repo update

helm install -n ct-dev api calltelemetry/api -f my-values.yaml
helm install -n ct-dev ct-web calltelemetry/ct-web -f my-values.yaml
```

See the [Installation Guide](docs/haproxy-calltelemetry-installation-guide.md) for the full step-by-step walkthrough.

## Platform-Specific Setup

### On-Prem / K3s (Bare Metal)

Requires MetalLB for external IP assignment. Helmfile installs it automatically, or install manually:

```bash
helm install metallb metallb/metallb -n metallb-system --create-namespace
```

The ingress chart creates MetalLB `IPAddressPool` and `L2Advertisement` resources. You assign static IPs in your values file.

### DigitalOcean (DOKS)

No MetalLB needed. LoadBalancer services automatically provision DO Load Balancers. Override storage in your values:

```yaml
# postgresql values
cluster:
  storage:
    storageClass: do-block-storage
```

### AWS EKS

No MetalLB needed. LoadBalancer services provision AWS NLBs. Requires the [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) and [EBS CSI Driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html).

```yaml
cluster:
  storage:
    storageClass: gp3
```

### Azure AKS

No MetalLB needed. LoadBalancer services provision Azure Load Balancers.

```yaml
cluster:
  storage:
    storageClass: managed-csi
```

## Database Options

### CloudNativePG (Recommended)

The `postgresql` chart deploys a CNPG Cluster CR. The CNPG operator must be installed first (Helmfile handles this automatically).

```bash
helm install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace --wait
```

See [PostgreSQL Chart README](helm/charts/postgresql/README.md) for configuration.

### Crunchy PGO (Legacy)

For environments with an existing Crunchy Data PostgreSQL Operator:

1. PGO operator must be running in `postgres-operator` namespace
2. Copy the PGO secret to the application namespace:

```bash
kubectl -n postgres-operator get secret hippo-pguser-calltelemetry -o json \
  | jq 'del(.metadata["namespace","creationTimestamp","resourceVersion","selfLink","uid","ownerReferences","managedFields"])' \
  | kubectl apply -n ct-dev -f -
```

3. Skip the CNPG operator and postgresql chart — configure the API chart to use the PGO secret directly.

## Helm v4 Compatibility

This repo uses `--server-side=false` in helmDefaults. Helm v4 defaults to Server-Side Apply (SSA), which conflicts with controllers that mutate their own resources at runtime (MetalLB, CNPG). Disabling SSA is the correct setting for single-tenant clusters.

## Automated Chart Versioning

A GitHub Actions workflow automatically detects chart changes, increments patch versions (semver), packages charts, and publishes to GitHub Pages.

## Adding the Helm Repository

```bash
helm repo add calltelemetry https://calltelemetry.github.io/k8s/helm/charts
helm repo update
```

## Tests

```bash
./tests/unit/test-metallb-namespace.sh -f ./your-values.yaml
./tests/integration/test-multi-namespace.sh
```

See [Helm Chart TDD](helm-chart-tdd.md) for details.
