# Detailed Architecture Diagram: MetalLB Integration

This document provides a detailed architecture diagram showing how the ingress chart integrates with MetalLB.

```mermaid
graph TD
    subgraph "Kubernetes Cluster"
        subgraph "metallb-system Namespace"
            IPPool1[IPAddressPool: primary-ip-namespace1]
            IPPool2[IPAddressPool: secondary-ip-namespace1]
            IPPool3[IPAddressPool: admin-ip-namespace1]

            IPPool4[IPAddressPool: primary-ip-namespace2]
            IPPool5[IPAddressPool: secondary-ip-namespace2]
            IPPool6[IPAddressPool: admin-ip-namespace2]

            L2Advert1[L2Advertisement: primary-l2-advert-namespace1]
            L2Advert2[L2Advertisement: secondary-l2-advert-namespace1]
            L2Advert3[L2Advertisement: admin-l2-advert-namespace1]

            L2Advert4[L2Advertisement: primary-l2-advert-namespace2]
            L2Advert5[L2Advertisement: secondary-l2-advert-namespace2]
            L2Advert6[L2Advertisement: admin-l2-advert-namespace2]

            IPPool1 --> L2Advert1
            IPPool2 --> L2Advert2
            IPPool3 --> L2Advert3

            IPPool4 --> L2Advert4
            IPPool5 --> L2Advert5
            IPPool6 --> L2Advert6
        end

        subgraph "namespace1"
            Service1[Service: release1-primary-api-external\nType: LoadBalancer\nAnnotation: metallb.universe.tf/address-pool: primary-ip-namespace1]
            Service2[Service: release1-secondary-api-external\nType: LoadBalancer\nAnnotation: metallb.universe.tf/address-pool: secondary-ip-namespace1]
            Service3[Service: release1-admin-lb\nType: LoadBalancer\nAnnotation: metallb.universe.tf/address-pool: admin-ip-namespace1]

            IngressController1[Deployment: release1-ingress-nginx-controller]

            Service1 --> IngressController1
            Service2 --> IngressController1
            Service3 --> IngressController1
        end

        subgraph "namespace2"
            Service4[Service: release2-primary-api-external\nType: LoadBalancer\nAnnotation: metallb.universe.tf/address-pool: primary-ip-namespace2]
            Service5[Service: release2-secondary-api-external\nType: LoadBalancer\nAnnotation: metallb.universe.tf/address-pool: secondary-ip-namespace2]
            Service6[Service: release2-admin-lb\nType: LoadBalancer\nAnnotation: metallb.universe.tf/address-pool: admin-ip-namespace2]

            IngressController2[Deployment: release2-ingress-nginx-controller]

            Service4 --> IngressController2
            Service5 --> IngressController2
            Service6 --> IngressController2
        end

        L2Advert1 --> Service1
        L2Advert2 --> Service2
        L2Advert3 --> Service3

        L2Advert4 --> Service4
        L2Advert5 --> Service5
        L2Advert6 --> Service6
    end
```

## Architecture Explanation

### MetalLB Resources in metallb-system Namespace

All MetalLB resources (IPAddressPool and L2Advertisement) are created in the `metallb-system` namespace, as required by MetalLB's admission webhook. However, they are named with the namespace of the release to avoid conflicts:

- `primary-ip-namespace1` for the primary API in namespace1
- `secondary-ip-namespace1` for the secondary API in namespace1
- `admin-ip-namespace1` for the admin API in namespace1

And similarly for namespace2.

### Services in Release Namespaces

Services are created in their respective release namespaces, but they reference the MetalLB resources in the `metallb-system` namespace using annotations:

```yaml
metallb.universe.tf/address-pool: primary-ip-namespace1
```

This allows multiple releases in different namespaces to use MetalLB without conflicts, while respecting MetalLB's requirement that its resources be created in the `metallb-system` namespace.

### Ingress Controllers

Each release has its own ingress controller deployment, which is referenced by the services in that namespace. This allows for complete isolation between releases, with each having its own set of load balancers and ingress controllers.

## Multi-Namespace Deployment

This architecture supports deploying the chart in multiple namespaces without conflicts:

1. Each namespace gets its own set of MetalLB resources in the `metallb-system` namespace, with namespace-specific names
2. Each namespace gets its own set of services that reference the corresponding MetalLB resources
3. Each namespace gets its own ingress controller deployment

This approach provides complete isolation between releases while respecting MetalLB's requirements.
