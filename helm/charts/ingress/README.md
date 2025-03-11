# Ingress Chart

This Helm chart deploys an NGINX ingress controller with MetalLB support for Kubernetes.

## Features

- Namespace-aware service account names
- Support for multiple load balancers (primary API, secondary API, admin)
- MetalLB integration for bare metal Kubernetes clusters
- Configurable RBAC settings
- Multi-namespace deployment support with no conflicts

## Installation

```bash
helm install ingress ./helm/charts/ingress -n your-namespace
```

## Configuration

### Namespace-Aware Service Accounts

The chart automatically creates service accounts with namespace-specific names. This allows you to deploy multiple instances of the ingress controller in different namespaces without conflicts.

For example, if you deploy in the `dev` namespace, the service account will be named `nginx-ingress-serviceaccount`.

### Multi-Namespace Deployment

This chart is designed to be deployed in multiple namespaces without conflicts. By default:

1. **ClusterRole creation is disabled** to avoid conflicts between different namespace installations
2. **Service account names are namespace-aware** to avoid conflicts
3. **All resources are namespaced** where possible

If you need to create ClusterRoles, you can enable them in your values file:

```yaml
ingress-nginx:
  controller:
    clusterRole:
      create: true
      # This will create a unique ClusterRole per namespace
      name: "ingress-nginx-your-namespace"
```

Make sure to use a unique name for each namespace to avoid conflicts.

### Load Balancers

The chart supports three load balancers:

1. **Primary API Load Balancer**: For the main API traffic
2. **Secondary API Load Balancer**: For secondary API traffic
3. **Admin Load Balancer**: For admin traffic

Each load balancer can be enabled/disabled independently and configured with its own IP address and ports.

### Example Values

```yaml
# dev-ingress.yaml
metallb:
  enabled: false

# Primary API Load Balancer
primary_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true

# Secondary API Load Balancer
secondary_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true

# Admin API Load Balancer
admin_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true

ingress-nginx:
  controller:
    replicaCount: 1
    # No need to specify serviceAccount.name - it will be automatically set based on namespace
```

## Upgrading

When upgrading from a previous version, make sure to check the release notes for any breaking changes.

## Troubleshooting

### Common Issues

1. **Load balancer not getting an IP address**: Make sure MetalLB is properly configured and the address pools exist.
2. **Ingress controller not routing traffic**: Check that the service selectors match the pod labels.
3. **Permission issues**: Verify that the RBAC settings are correct for your cluster.

## Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `metallb.enabled` | Enable MetalLB integration | `false` |
| `ingress-nginx.controller.replicaCount` | Number of ingress controller replicas | `1` |
| `ingress-nginx.controller.serviceAccount.name` | Name of the service account | `nginx-ingress-serviceaccount` |
| `primary_api.createLoadBalancer` | Create primary API load balancer | `false` |
| `primary_api.advertiseL2MetalLb` | Advertise primary API load balancer via MetalLB L2 | `false` |
| `primary_api.ip` | IP address for primary API load balancer | `192.168.123.205` |
| `secondary_api.createLoadBalancer` | Create secondary API load balancer | `false` |
| `admin_api.createLoadBalancer` | Create admin load balancer | `true` |
