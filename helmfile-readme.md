# CallTelemetry Helmfile Deployment

This helmfile provides a simple way to deploy the entire CallTelemetry environment based on an environment value. It automates the deployment of all required components in the correct order.

## Prerequisites

- Kubernetes cluster (v1.30+)
- Helm 3 installed
- Helmfile installed
- `kubectl` configured to communicate with your cluster

## Installation

### Install Required Tools

1. Install Helmfile:

```bash
# On macOS
brew install helmfile

# On Linux
curl -L https://github.com/helmfile/helmfile/releases/latest/download/helmfile_linux_amd64 > /usr/local/bin/helmfile
chmod +x /usr/local/bin/helmfile
```

2. Install the Helm Diff Plugin (required by Helmfile):

```bash
helm plugin install https://github.com/databus23/helm-diff
```

This plugin is required for Helmfile to show differences between the current state and the desired state before applying changes.

## Repository Setup

Clone this repository:

```bash
git clone https://github.com/calltelemetry/k8s.git
cd k8s
```

## Usage

The helmfile is configured to deploy the entire CallTelemetry environment based on the environment specified. It ships two illustrative environments plus a single-node appliance environment:

- `dev` - Development-style environment (uses env-common.yaml and env-dev.yaml)
- `prod` - Production-style environment (uses env-common.yaml and env-prod.yaml)
- `ct-appliance` - Single-node K3s appliance (uses env-common.yaml and env-appliance.yaml)

Copy and adapt the `env-*.yaml` files and the values files under `examples/` for
your own cluster names, domains, and MetalLB addresses before deploying.

### Deploy the Development Environment

```bash
# With diff (recommended)
helmfile --environment dev apply

# Without diff (if helm-diff plugin is not installed)
helmfile --environment dev apply --skip-diff
```

This will:
1. Create the target namespace if it doesn't exist
2. Apply the shared RBAC resources
3. Install MetalLB if needed
4. Install HAProxy Ingress Controller
5. Install the CT Ingress Configs
6. Install NATS Server
7. Install Call Telemetry API
8. Install Vue Web Frontend
9. Install Traceroute Service

### Deploy the Production Environment

```bash
helmfile --environment prod apply
```

This will deploy the same components but with production-specific configurations.

## Customization

### Environment Files

The helmfile uses environment files to configure the deployment:

- `env-common.yaml` - Common configuration shared between all environments
- `env-dev.yaml` - Development-specific configuration
- `env-prod.yaml` - Production-specific configuration

These files contain references to the values files in the `examples` directory:

- `haproxy-example-values.yaml` - HAProxy configuration
- `ingress-example-values.yaml` - Ingress configuration (MetalLB)
- `api-example-values.yaml` - API configuration
- `vue-web-example-values.yaml` - Vue Web configuration
- `traceroute-example-values.yaml` - Traceroute configuration
- `nats-dev-values.yaml` / `nats-prod-values.yaml` - NATS configuration
- `postgresql-dev-values.yaml` / `postgresql-prod-values.yaml` - PostgreSQL configuration

To customize the deployment, you can either:
1. Modify the environment files to point to different values files
2. Modify the values files directly

## Troubleshooting


### General Troubleshooting

If you encounter issues during deployment, you can check the status of the releases:

```bash
helmfile --environment dev status
```

To see detailed logs for a specific release:

```bash
helmfile --environment dev --selector name=api logs
```

To delete all releases:

```bash
helmfile --environment dev destroy
```

## Architecture

Each product release renders its own chart-level README under
`helm/charts/<chart>/README.md`. Start with `helm/charts/calltelemetry/README.md`
for the standard product stack chart, and `helm/charts/api/README.md` for the
API chart's TrueSpam credential-encryption Secret contract.
