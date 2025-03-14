# Traceroute Helm Chart

This Helm chart deploys the CallTelemetry Traceroute service, which provides network diagnostic capabilities for the CallTelemetry platform.

## Overview

The Traceroute service is responsible for performing network diagnostics and traceroute operations for the CallTelemetry platform. It communicates with the API service via NATS and provides valuable network path information.

## Prerequisites

- Kubernetes 1.30+
- Helm 3.0+
- NATS Chart deployed

For a complete installation guide of the entire CallTelemetry platform, please refer to the [HAProxy CallTelemetry Installation Guide](../../haproxy-calltelemetry-installation-guide.md).

## Installation

### Using Helm

```bash
# Add the CallTelemetry Helm repository (if not already added)
helm repo add calltelemetry https://calltelemetry.github.io/k8s/helm/charts

# Update the repository
helm repo update

# Install the chart with the release name "traceroute"
helm install traceroute calltelemetry/traceroute -n ct-dev
helm install traceroute calltelemetry/traceroute -n ct-prod
```

## Configuration

The following table lists the configurable parameters of the Traceroute chart and their default values.

| Parameter                        | Description                                      | Default                     |
|----------------------------------|--------------------------------------------------|----------------------------- |
| `replicaCount`                   | Number of replicas                               | `1`                         |
| `image.repository`               | Image repository                                 | `calltelemetry/traceroute`  |
| `image.tag`                      | Image tag                                        | `0.8.3`                     |
| `image.pullPolicy`               | Image pull policy                                | `IfNotPresent`              |
| `resources.requests.cpu`         | CPU resource requests                            | `256m`                      |
| `resources.limits.cpu`           | CPU resource limits                              | `1`                         |
| `nats.server`                    | NATS server hostname                             | `nats`                      |
| `service.type`                   | Kubernetes service type                          | `ClusterIP`                 |
| `service.port`                   | Service port                                     | `4100`                      |
| `service.targetPort`             | Service target port                              | `4100`                      |
| `securityContext.runAsUser`      | User ID to run the container                     | `0`                         |
| `terminationGracePeriodSeconds`  | Pod termination grace period                     | `5`                         |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

For example:

```bash
helm install traceroute calltelemetry/traceroute
```

Alternatively, a YAML file that specifies the values for the parameters can be provided while installing the chart. For example:

```bash
helm install traceroute calltelemetry/traceroute -n ct-dev -f examples/traceroute-ct-dev-values.yaml
helm install traceroute calltelemetry/traceroute -n ct-prod -f examples/traceroute-ct-prod-values.yaml
```

## Example Values Files

Example values files for development and production environments are provided in the `examples` directory:

- `examples/traceroute-ct-dev-values.yaml`: Development environment configuration
- `examples/traceroute-ct-prod-values.yaml`: Production environment configuration

## Integration with CallTelemetry Platform

The Traceroute service is designed to work with the CallTelemetry API service. The API service communicates with the Traceroute service via NATS.

To configure the API service to use this Traceroute service, set the `TRACEROUTE_SERVICE` environment variable in the API deployment to `traceroute`.

### Installing as Part of CallTelemetry Platform

To install the Traceroute chart as part of the complete CallTelemetry platform, follow the instructions in the [HAProxy CallTelemetry Installation Guide](../../haproxy-calltelemetry-installation-guide.md).

```bash
# Install in ct-dev namespace
helm install traceroute calltelemetry/traceroute -n ct-dev -f examples/traceroute-ct-dev-values.yaml

# Install in ct-prod namespace
helm install traceroute calltelemetry/traceroute -n ct-prod -f examples/traceroute-ct-prod-values.yaml
```

## Uninstalling the Chart

To uninstall/delete the `traceroute` deployment:

```bash
helm uninstall traceroute -n ct-dev
helm uninstall traceroute -n ct-prod
```
