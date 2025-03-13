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

The following diagram illustrates the high-level architecture of the Call Telemetry deployment with HAProxy in a Kubernetes cluster:

```mermaid
graph TD
    classDef centerClass text-align:center;

    Client[External Client]:::centerClass -->|HTTP/HTTPS/SSH| PhysicalNetwork[Physical Network]:::centerClass
    PhysicalNetwork -->|Layer 2 Traffic| MetalLB[MetalLB Load Balancer]

    subgraph "Kubernetes Cluster"
        subgraph "metallb-system Namespace"
            MetalLB
            IPPoolDev1[IPAddressPool: primary-ip-ct-dev]
            IPPoolDev2[IPAddressPool: secondary-ip-ct-dev]
            IPPoolDev3[IPAddressPool: admin-ip-ct-dev]

            IPPoolProd1[IPAddressPool: primary-ip-ct-prod]
            IPPoolProd2[IPAddressPool: secondary-ip-ct-prod]
            IPPoolProd3[IPAddressPool: admin-ip-ct-prod]
        end

        subgraph "ct-dev Namespace"
            LB1[Primary API LoadBalancer 192.168.123.235]
            LB2[Secondary API LoadBalancer 192.168.123.236]
            LB3[Admin API LoadBalancer 192.168.123.237]

            HAProxyDev[HAProxy Ingress Controller]

            subgraph "Helm Charts - ct-dev"
                APIDev[API Chart]
                EchoDev[Echo Chart]
                VueWebDev[Vue Web Chart]
            end

            LB1 -->|Routes Traffic| HAProxyDev
            LB2 -->|Routes Traffic| HAProxyDev
            LB3 -->|Routes Traffic| HAProxyDev

            HAProxyDev -->|Routes Based on Rules| APIDev
            HAProxyDev -->|Routes Based on Rules| EchoDev
            HAProxyDev -->|Routes Based on Rules| VueWebDev
        end

        subgraph "ct-prod Namespace"
            LB4[Primary API LoadBalancer 192.168.123.225]
            LB5[Secondary API LoadBalancer 192.168.123.226]
            LB6[Admin API LoadBalancer 192.168.123.227]

            HAProxyProd[HAProxy Ingress Controller]

            subgraph "Helm Charts - ct-prod"
                APIProd[API Chart]
                EchoProd[Echo Chart]
                VueWebProd[Vue Web Chart]
            end

            LB4 -->|Routes Traffic| HAProxyProd
            LB5 -->|Routes Traffic| HAProxyProd
            LB6 -->|Routes Traffic| HAProxyProd

            HAProxyProd -->|Routes Based on Rules| APIProd
            HAProxyProd -->|Routes Based on Rules| EchoProd
            HAProxyProd -->|Routes Based on Rules| VueWebProd
        end

        IPPoolDev1 -->|Routes Traffic| LB1
        IPPoolDev2 -->|Routes Traffic| LB2
        IPPoolDev3 -->|Routes Traffic| LB3

        IPPoolProd1 -->|Routes Traffic| LB4
        IPPoolProd2 -->|Routes Traffic| LB5
        IPPoolProd3 -->|Routes Traffic| LB6
    end
```

### Port Mapping Diagram

The following diagram illustrates how external ports on the load balancers map to internal services and pods:

```mermaid
graph LR
    classDef externalClass fill:#f9f,stroke:#333,stroke-width:2px;
    classDef serviceClass fill:#bbf,stroke:#333,stroke-width:1px;
    classDef podClass fill:#bfb,stroke:#333,stroke-width:1px;

    %% External Load Balancers
    LB1[Admin LB 192.168.123.237]:::externalClass
    LB2[Primary LB 192.168.123.235]:::externalClass
    LB3[Secondary LB 192.168.123.236]:::externalClass

    %% HAProxy Service
    HAProxy[HAProxy Service]:::serviceClass

    %% Internal Services
    API[API Service]:::serviceClass
    SFTP[SFTP Service]:::serviceClass
    VueWeb[Vue Web Service]:::serviceClass

    %% Pods
    APIPod[API Pod Port: 4000]:::podClass
    SFTPPod[SFTP Pod Port: 2222]:::podClass
    VueWebPod[Vue Web Pod Port: 80]:::podClass

    %% External to HAProxy connections
    LB1 -->|Port 80| HAProxy
    LB1 -->|Port 443| HAProxy
    LB1 -->|Port 22| HAProxy
    LB1 -->|Port 514| HAProxy

    LB2 -->|Port 80| HAProxy
    LB2 -->|Port 443| HAProxy

    LB3 -->|Port 80| HAProxy
    LB3 -->|Port 443| HAProxy

    %% HAProxy to Services connections
    HAProxy -->|HTTP Routes| API
    HAProxy -->|HTTP Routes| VueWeb
    HAProxy -->|TCP Port 22| SFTP
    HAProxy -->|TCP Port 514| SFTP

    %% Services to Pods connections
    API -->|Port 4000| APIPod
    SFTP -->|Port 2222| SFTPPod
    VueWeb -->|Port 80| VueWebPod
```

The deployment consists of the following components:

1. **MetalLB** - Layer 2 load balancer for Kubernetes (bare metal)
   - Provides external IP addresses for services
   - Configured with a range of IPs for the cluster
2. **HAProxy Ingress Controller** - Routes external traffic to services
    - Configured with multiple Ingress resources for different environments
    - Handles TCP services for SFTP and Syslog
    - Uses shared RBAC resources for multi-namespace deployment
3. **NATS Server** - Message broker for inter-service communication
    - Configured with JetStream for persistent messaging
    - Deployed in both ct-dev and ct-prod namespaces
4. **PostgreSQL Database** - Data storage
5. **Call Telemetry API** - Core application services
6. **Vue Web Frontend** - User interface for Call Telemetry

## Add Required Helm Repositories

First, add all the necessary Helm repositories:

```bash
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
helm repo add metallb https://metallb.github.io/metallb
helm repo add nats https://nats-io.github.io/k8s/helm/charts
helm repo add calltelemetry https://calltelemetry.github.io/k8s/helm/charts
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

When deploying HAProxy in multiple namespaces, you need to create shared RBAC resources to avoid conflicts with cluster-wide resources like ClusterRoles.

1. Use the provided `examples/haproxy-shared-rbac-narrow.yaml` file which contains:
   - A shared ClusterRole with all necessary permissions
   - ServiceAccounts for each namespace (ct-dev and ct-prod)
   - ClusterRoleBindings that grant permissions to the ServiceAccounts

2. Apply the shared RBAC resources:

```bash
kubectl apply -f examples/haproxy-shared-rbac-narrow.yaml
```

This grants the necessary permissions to the service accounts in both namespaces, so you don't need to update the RBAC configuration when deploying HAProxy in each namespace.

## Install HAProxy Ingress Controller in Multiple Namespaces

After applying the shared RBAC resources, you can install HAProxy in both namespaces. HAProxy handles ingress traffic and routes it to the appropriate services.

The example values files (`examples/haproxy-ct-dev-values.yaml` and `examples/haproxy-ct-prod-values.yaml`) include:
- Disabled RBAC creation (using the shared RBAC resources)
- Existing ServiceAccount configuration
- Namespace-specific IngressClass names
- TCP services configuration for SFTP and Syslog

```bash
# Install in ct-dev namespace
helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-dev -f examples/haproxy-ct-dev-values.yaml

# Install in ct-prod namespace
helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-prod -f examples/haproxy-ct-prod-values.yaml
```

## Install the CT Ingress Configs

Each namespace has its own Ingress configuration that routes traffic to the Call Telemetry API services. This layer allows you to configure load balancing concerns without impacting the API Service Chart.

The example values files (`examples/ingress-ct-dev-values.yaml` and `examples/ingress-ct-prod-values.yaml`) include:
- Load balancer configurations for primary, secondary, and admin APIs
- MetalLB IP address assignments
- SFTP and Syslog port configurations
- HAProxy selector configuration

```bash
# Install in ct-dev namespace
helm install ingress-haproxy helm/charts/ingress -n ct-dev -f examples/ingress-ct-dev-values.yaml

# Install in ct-prod namespace
helm install ingress-haproxy helm/charts/ingress -n ct-prod -f examples/ingress-ct-prod-values.yaml
```

## Install NATS Server

NATS is a lightweight messaging system that Call Telemetry uses for inter-service communication. The example values file (`examples/nats-values.yaml`) configures NATS with JetStream enabled for persistent messaging.

```bash
# Install in ct-dev namespace
helm install nats nats/nats -n ct-dev -f examples/nats-values.yaml

# Install in ct-prod namespace
helm install nats nats/nats -n ct-prod -f examples/nats-values.yaml
```

## Set Up PostgreSQL Database

Call Telemetry requires a PostgreSQL database for data storage. You can either use an external PostgreSQL instance or deploy one within your Kubernetes cluster.

### Option 1: Crunchy PostgreSQL


## Install Call Telemetry API

This chart deploys the Call Telemetry API and its immediate dependencies. The example values files (`examples/api-ct-dev-values.yaml` and `examples/api-ct-prod-values.yaml`) include:
- Database configuration with existing secret
- Admin service configuration with SSH port
- SFTP server configuration
- Syslog configuration

```bash
# Install in ct-dev namespace
helm install api helm/charts/api -n ct-dev -f examples/api-ct-dev-values.yaml

# Install in ct-prod namespace
helm install api helm/charts/api -n ct-prod -f examples/api-ct-prod-values.yaml
```

## Install Vue Web Frontend

The Vue Web frontend provides the user interface for Call Telemetry. The example values files (`examples/vue-web-ct-dev-values.yaml` and `examples/vue-web-ct-prod-values.yaml`) include:
- Service configuration
- Ingress configuration with HAProxy-specific annotations
- Session cookie configuration

```bash
# Install in ct-dev namespace
helm install vue-web helm/charts/vue-web -n ct-dev -f examples/vue-web-ct-dev-values.yaml

# Install in ct-prod namespace
helm install vue-web helm/charts/vue-web -n ct-prod -f examples/vue-web-ct-prod-values.yaml
```

## Verify the Installation

Check that all pods are running in both namespaces:

```bash
# Check ct-dev namespace
kubectl get pods -n ct-dev

# Check ct-prod namespace
kubectl get pods -n ct-prod
```

Verify the services and their external IPs:

```bash
# Check ct-dev namespace
kubectl get services -n ct-dev

# Check ct-prod namespace
kubectl get services -n ct-prod
```

Check the ingress resources:

```bash
# Check ct-dev namespace
kubectl get ingress -n ct-dev

# Check ct-prod namespace
kubectl get ingress -n ct-prod
```

## Testing the Deployment

Test the API endpoints using curl for both environments:

```bash
# Test the dev environment
# Test the admin API
curl -H "Host: dev.calltelemetry.com" http://192.168.123.237/api

# Test the primary API
curl -H "Host: dev.calltelemetry.com" http://192.168.123.235/api/policy

# Test the prod environment
# Test the admin API
curl -H "Host: prod.calltelemetry.com" http://192.168.123.217/api

# Test the primary API
curl -H "Host: prod.calltelemetry.com" http://192.168.123.225/api/policy
```

## Troubleshooting

### Database Connection Issues

If the API pods are having trouble connecting to the database, verify the database secret:

```bash
# For ct-dev namespace
kubectl get secret hippo-pguser-calltelemetry -n ct-dev -o jsonpath='{.data}' | jq

# For ct-prod namespace
kubectl get secret hippo-pguser-calltelemetry -n ct-prod -o jsonpath='{.data}' | jq
```

### Ingress Routing Issues

Check the HAProxy Ingress Controller logs:

```bash
# For ct-dev namespace
kubectl logs -n ct-dev -l app.kubernetes.io/name=haproxy-ingress

# For ct-prod namespace
kubectl logs -n ct-prod -l app.kubernetes.io/name=haproxy-ingress
```

### SFTP Connection Issues

If you're having trouble connecting to the SFTP server, verify that HAProxy is properly configured to forward port 22:

```bash
# Check if HAProxy is listening on port 22
kubectl exec -n ct-dev $(kubectl get pods -n ct-dev -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].metadata.name}') -- netstat -tulpn | grep ":22"

# Check the TCP services configmap
kubectl get configmap -n ct-dev haproxy-tcp-services -o yaml
```

### Pod Startup Issues

Check the logs of the failing pods:

```bash
# For ct-dev namespace
kubectl logs -n ct-dev <pod-name>

# For ct-prod namespace
kubectl logs -n ct-prod <pod-name>
```

## Conclusion

You now have a fully functional Call Telemetry deployment with HAProxy as the ingress controller. This setup provides high availability and scalability for production environments.

For more information on customizing your deployment, refer to the Call Telemetry documentation.
