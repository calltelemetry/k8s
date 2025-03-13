# Installing Call Telemetry with HAProxy Ingress Controller

This guide walks through the complete installation of Call Telemetry using HAProxy as the ingress controller in a Kubernetes environment. We'll cover everything from adding the necessary Helm repositories to configuring all components for a production-ready deployment.

## Prerequisites

- Kubernetes cluster (v1.30+)
- Helm 3 installed
- `kubectl` configured to communicate with your cluster
``` bash
mkdir -p ~/.kube
sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config
```

## Architecture Overview
# K8S Diagram

The deployment consists of the following components:

1. **MetalLB** - Layer 2 load balancer for Kubernetes
2. **HAProxy Ingress Controller** - Routes external traffic to services
3. **NATS Server** - Message broker for inter-service communication
4. **PostgreSQL Database** - Data storage
5. **Call Telemetry API** - Core application services

## Step 1: Add Required Helm Repositories

First, add all the necessary Helm repositories:

```bash
# Add HAProxy Ingress repository
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts

# Add MetalLB repository
helm repo add metallb https://metallb.github.io/metallb

# Add NATS repository
helm repo add calltelemetry https://calltelemetry.github.io/k8s/helm/charts

# Add Call Telemetry repository
helm repo add calltelemetry

# Update repositories
helm repo update
```


## Cluster Wide Install and Configure MetalLB - Bare Metal Load Balancer

MetalLB provides external IP addresses for Kubernetes services.

```bash
helm install metallb metallb/metallb -n metallb-system
```


## Create ct-dev and ct-prod Namespace

Create dedicated namespaces for the Call Telemetry deployment Dev and Prod environments:

```bash
kubectl create namespace ct-dev
kubectl create namespace ct-prod
```

## Create Shared RBAC Resources for Multi-Namespace Deployment

When deploying HAProxy in multiple namespaces, you also need to create shared RBAC resources to avoid conflicts with cluster-wide resources like ClusterRoles.

1. Use the provided `haproxy-shared-rbac-narrow.yaml` file which contains:
   - A shared ClusterRole with all necessary permissions
   - A ClusterRoleBinding that grants permissions a ServiceAccount for the 2 expected namespaces in the cluster

2. Apply the shared RBAC resources:

```bash
kubectl apply -f haproxy-shared-rbac-narrow.yaml
```

This grants the necessary permissions to the service account, so you don't need to update the RBAC configuration when adding new namespaces.

## Install HAProxy Ingress Controller in Multiple Namespaces

After applying the shared RBAC resources, you can install HAProxy. HAProxy handles ingress traffic and routes it to the appropriate services.

```bash
# Install in ct-dev namespace
helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-dev -f haproxy-ct-dev-values.yaml

# Install in ct-prod namespace
helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-prod -f haproxy-ct-prod-values.yaml
```

## Install the CT Ingress Configs
Each namespace will have its own Ingress configuration. The Ingress configuration will be used to route traffic to the Call Telemetry API services.

```bash
helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-dev -f ingress-ct-dev-values.yaml

helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-dev -f ingress-ct-prod-values.yaml
```

## Install NATS Server

NATS is a lightweight messaging system that Call Telemetry uses for inter-service communication.

```bash
helm install nats nats/nats -n ct-dev -f nats-values.yaml
helm install nats nats/nats -n ct-prod -f nats-values.yaml
```

## Set Up PostgreSQL Database

Call Telemetry requires a PostgreSQL database for data storage. You can either use an external PostgreSQL instance or deploy one within your Kubernetes cluster.

### Option 1: Crunchy PostgreSQL


## Install Call Telemetry API
This chart deploys the Call Telemetry API and its immeidate dependencies.




```bash
helm install api helm/charts/api -n ct-dev -f prod-api.yaml
```

#

## Step 9: Verify the Installation

Check that all pods are running:

```bash
kubectl get pods -n calltelemetry
```

Verify the services and their external IPs:

```bash
kubectl get services -n calltelemetry
```

Check the ingress resources:

```bash
kubectl get ingress -n calltelemetry
```

## Step 10: Testing the Deployment

Test the API endpoints using curl:

```bash
# Test the admin API
curl -H "Host: dev.calltelemetry.com" http://192.168.123.237/api

# Test the primary API
curl -H "Host: dev.calltelemetry.com" http://192.168.123.235/api/policy
```

## Troubleshooting

### Database Connection Issues

If the API pods are having trouble connecting to the database, verify the database secret:

```bash
kubectl get secret hippo-pguser-hippo -n calltelemetry -o jsonpath='{.data}' | jq
```

### Ingress Routing Issues

Check the HAProxy Ingress Controller logs:

```bash
kubectl logs -n calltelemetry -l app.kubernetes.io/name=haproxy-ingress
```

### Pod Startup Issues

Check the logs of the failing pods:

```bash
kubectl logs -n calltelemetry <pod-name>
```

## Conclusion

You now have a fully functional Call Telemetry deployment with HAProxy as the ingress controller. This setup provides high availability and scalability for production environments.

For more information on customizing your deployment, refer to the Call Telemetry documentation.
