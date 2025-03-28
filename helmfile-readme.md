# CallTelemetry Helmfile Deployment

This helmfile provides a simple way to deploy the entire CallTelemetry environment based on a namespace value. It automates the deployment of all required components in the correct order.

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
git clone https://github.com/calltelemetry/k8s-charts.git
cd k8s-charts
```

## Usage

The helmfile is configured to deploy the entire CallTelemetry environment based on the environment specified. It supports two environments with separate configuration files:

- `ct-dev` - Development environment (uses env-common.yaml and env-dev.yaml)
- `ct-prod` - Production environment (uses env-common.yaml and env-prod.yaml)

This structure allows for easy customization and reuse of common configuration values.

### Deploy the Development Environment

```bash
# With diff (recommended)
helmfile --environment ct-dev apply

# Without diff (if helm-diff plugin is not installed)
helmfile --environment ct-dev apply --skip-diff
```

This will:
1. Create the `ct-dev` namespace if it doesn't exist
2. Apply the shared RBAC resources
3. Install MetalLB if needed
4. Install HAProxy Ingress Controller
5. Install the CT Ingress Configs
6. Install NATS Server
7. Install Call Telemetry API
8. Install Vue Web Frontend
9. Install Microsoft Teams Authentication Service
10. Install Traceroute Service
11. Install Echo Service

### Deploy the Production Environment

```bash
helmfile --environment ct-prod apply
```

This will deploy the same components but with production-specific configurations.

## Customization

### Environment Files

The helmfile uses environment files to configure the deployment:

- `env-common.yaml` - Common configuration shared between all environments
- `env-dev.yaml` - Development-specific configuration
- `env-prod.yaml` - Production-specific configuration

These files contain references to the values files in the `examples` directory:

- `haproxy-ct-dev-values.yaml` - HAProxy configuration for development
- `ingress-ct-dev-values.yaml` - Ingress configuration for development
- `api-ct-dev-values.yaml` - API configuration for development
- `vue-web-ct-dev-values.yaml` - Vue Web configuration for development
- `teams-auth-ct-dev-values.yaml` - Teams Auth configuration for development
- `traceroute-ct-dev-values.yaml` - Traceroute configuration for development
- `echo-haproxy-ct-dev-values.yaml` - Echo configuration for development
- `nats-values.yaml` - NATS configuration (shared between environments)

To customize the deployment, you can either:
1. Modify the environment files to point to different values files
2. Modify the values files directly

## Troubleshooting


### General Troubleshooting

If you encounter issues during deployment, you can check the status of the releases:

```bash
helmfile --environment ct-dev status
```

To see detailed logs for a specific release:

```bash
helmfile --environment ct-dev --selector name=api logs
```

To delete all releases:

```bash
helmfile --environment ct-dev destroy
```

## Architecture

The deployment follows the architecture described in the [CallTelemetry Installation Guide](haproxy-calltelemetry-installation-guide.md).
