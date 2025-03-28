# Multi-Namespace Deployment Guide

This document explains how to deploy the ingress controller in multiple namespaces with complete isolation.

## Understanding the Issue

When deploying the ingress controller in multiple namespaces, several cluster-wide resources can cause conflicts:

1. **ClusterRole**: The RBAC ClusterRole is a cluster-wide resource
2. **IngressClass**: The IngressClass resource is cluster-wide
3. **MetalLB IPAddressPool**: The IPAddressPool resources are cluster-wide
4. **MetalLB L2Advertisement**: The L2Advertisement resources are cluster-wide

## Solution

The chart has been updated to make all these resources namespace-aware by:

1. Including the namespace in the resource names
2. Using unique names for each namespace deployment
3. Supporting customizable annotations and selectors

## Deployment Instructions

### Step 1: Deploy in First Namespace (e.g., Development)

Create a dev-ingress.yaml file:

```yaml
# Development environment configuration
metallb:
  enabled: true

# Load Balancer Common Configuration
loadBalancer:
  # Ingress class annotation - used by all load balancers
  ingressClass: nginx-dev
  # Common annotations for all load balancers
  annotations:
    # The selector is specified as annotations for more flexibility
    kubernetes.io/ingress.class: nginx-dev
    # Selector for the ingress controller pods
    ingress.kubernetes.io/selector-component: controller
    ingress.kubernetes.io/selector-instance: ingress
    ingress.kubernetes.io/selector-name: ingress-nginx
    # Environment label
    environment: development

# Primary API Load Balancer
primary_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true
  ip: "192.168.123.205"
  port: 80
  https_port: 443
  addressPool: "primary-api-ip-dev"
  # Custom annotations for this load balancer
  annotations:
    primary.api/environment: "development"

# Secondary API Load Balancer
secondary_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true
  ip: "192.168.123.206"
  port: 80
  https_port: 443
  addressPool: "secondary-api-ip-dev"

# Admin API Load Balancer
admin_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true
  ip: "192.168.123.207"
  port: 80
  https_port: 443
  addressPool: "admin-ip-dev"

# Ingress Nginx Configuration - IMPORTANT for multi-namespace deployment
ingress-nginx:
  controller:
    # Create a dev-specific ClusterRole with a unique name
    clusterRole:
      create: true
      name: "ingress-nginx-dev"

    # Use a unique IngressClass name for development
    ingressClassResource:
      name: nginx-dev
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-dev"

    # Set a unique name for other cluster-wide resources
    electionID: ingress-controller-leader-dev

    # Add environment label
    podLabels:
      environment: development
```

Install in the dev namespace:

```bash
helm install -n ct-dev ingress calltelemetry/ct-ingress -f dev-ingress.yaml
```

### Step 2: Deploy in Second Namespace (e.g., Production)

Create a prod-ingress.yaml file:

```yaml
# Production environment configuration
metallb:
  enabled: true

# Load Balancer Common Configuration
loadBalancer:
  # Ingress class annotation - used by all load balancers
  ingressClass: nginx-prod
  # Common annotations for all load balancers
  annotations:
    # The selector is specified as annotations for more flexibility
    kubernetes.io/ingress.class: nginx-prod
    # Selector for the ingress controller pods
    ingress.kubernetes.io/selector-component: controller
    ingress.kubernetes.io/selector-instance: ingress
    ingress.kubernetes.io/selector-name: ingress-nginx
    # Environment label
    environment: production

# Primary API Load Balancer
primary_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true
  ip: "192.168.123.215"
  port: 80
  https_port: 443
  addressPool: "primary-api-ip-prod"
  # Custom annotations for this load balancer
  annotations:
    primary.api/environment: "production"

# Secondary API Load Balancer
secondary_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true
  ip: "192.168.123.216"
  port: 80
  https_port: 443
  addressPool: "secondary-api-ip-prod"

# Admin API Load Balancer
admin_api:
  createLoadBalancer: true
  advertiseL2MetalLb: true
  ip: "192.168.123.217"
  port: 80
  https_port: 443
  addressPool: "admin-ip-prod"

# Ingress Nginx Configuration - IMPORTANT for multi-namespace deployment
ingress-nginx:
  controller:
    # Create a prod-specific ClusterRole with a unique name
    clusterRole:
      create: true
      name: "ingress-nginx-prod"

    # Use a unique IngressClass name for production
    ingressClassResource:
      name: nginx-prod
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-prod"

    # Set a unique name for other cluster-wide resources
    electionID: ingress-controller-leader-prod

    # Add environment label
    podLabels:
      environment: production
```

Install in the prod namespace:

```bash
helm install -n ct-prod ingress calltelemetry/ct-ingress -f prod-ingress.yaml
```

## How It Works

The chart now automatically includes the namespace in the names of all cluster-wide resources:

1. **MetalLB IPAddressPool**: Names now include the namespace (e.g., `admin-ip-ct-dev`, `admin-ip-ct-prod`)
2. **MetalLB L2Advertisement**: Names now include the namespace (e.g., `admin-l2-advert-ct-dev`, `admin-l2-advert-ct-prod`)

Additionally, the values file allows you to specify:

1. **ClusterRole**: Set a unique name like `ingress-nginx-dev` or `ingress-nginx-prod`
2. **IngressClass**: Set a unique name like `nginx-dev` or `nginx-prod`
3. **Election ID**: Set a unique election ID for leader election
4. **Annotations**: Customize annotations for each load balancer service
   - Common annotations can be set in `loadBalancer.annotations`
   - Service-specific annotations can be set in `primary_api.annotations`, etc.

This ensures that each namespace gets its own set of resources without conflicts.

## Testing

You can test the chart with the provided test script:

```bash
./test-charts.sh --chart ingress --values test-values.yaml
```

This will:
1. Lint the chart
2. Render the templates
3. Skip the dry-run installation (due to CRD ownership issues)

## Troubleshooting

If you encounter issues with the deployment, check:

1. **Resource Names**: Ensure that all resource names are unique across namespaces
2. **IngressClass**: Ensure that each namespace has a unique IngressClass
3. **ClusterRole**: Ensure that each namespace has a unique ClusterRole
4. **IP Addresses**: Ensure that each namespace has unique IP addresses for load balancers

## MetalLB Integration

The ingress chart creates MetalLB resources (IPAddressPool, L2Advertisement) in the `metallb-system` namespace. This is required because MetalLB's admission webhook only allows these resources to be created in the `metallb-system` namespace.

### MetalLB Resources

The chart creates the following MetalLB resources in the `metallb-system` namespace:

1. **IPAddressPool**: Defines the IP addresses that can be assigned to LoadBalancer services
   - Named with the namespace: `primary-ip-{namespace}`
   - Contains the IP address specified in the values file

2. **L2Advertisement**: Advertises the IP addresses to the network using Layer 2 protocol
   - Named with the namespace: `primary-l2-advert-{namespace}`
   - References the corresponding IPAddressPool

### Load Balancer Services

The chart creates LoadBalancer services that reference the MetalLB resources:

1. **Primary API Load Balancer**: `{release-name}-primary-api-external`
   - Uses the `primary-ip-{namespace}` address pool
   - Routes traffic to the Ingress Controller

2. **Secondary API Load Balancer**: `{release-name}-secondary-api-external`
   - Uses the `secondary-ip-{namespace}` address pool
   - Routes traffic to the Ingress Controller

3. **Admin Load Balancer**: `{release-name}-admin-lb`
   - Uses the `admin-ip-{namespace}` address pool
   - Routes traffic to the Ingress Controller

## Known Issues

### CRD Ownership

When installing the chart in a cluster where MetalLB is already installed, you may encounter the following error:

```
Error: INSTALLATION FAILED: Unable to continue with install: CustomResourceDefinition "bfdprofiles.metallb.io" in namespace "" exists and cannot be imported into the current release: invalid ownership metadata; annotation validation error: key "meta.helm.sh/release-name" must equal "ingress": current value is "metallb"; annotation validation error: key "meta.helm.sh/release-namespace" must equal "test-dev": current value is "metallb-system"
```

This happens because Helm tracks ownership of CRDs, and a CRD can only be owned by one release at a time. To resolve this issue, use the `--skip-crds` flag when installing the chart:

```bash
helm install -n your-namespace ingress ./helm/charts/ingress -f ./your-values.yaml --skip-crds
```

This will skip the installation of the MetalLB CRDs, which are already installed in the cluster.

### MetalLB Admission Webhook

MetalLB's admission webhook only allows IPAddressPool and L2Advertisement resources to be created in the `metallb-system` namespace. The chart has been updated to create these resources in the `metallb-system` namespace, but with names that include the namespace of the release to avoid conflicts.

For example, if you install the chart in the `test-dev` namespace, the following resources will be created:

- `primary-ip-test-dev` in the `metallb-system` namespace
- `primary-l2-advert-test-dev` in the `metallb-system` namespace

## MetalLB Integration

The ingress chart includes templates for MetalLB resources (IPAddressPool, L2Advertisement) but these resources must be created in the `metallb-system` namespace due to MetalLB's admission webhook configuration. This means that the chart cannot create these resources directly.

### Handling MetalLB Resources

There are several ways to handle this:

1. **Create MetalLB Resources Manually**: Create the IPAddressPool and L2Advertisement resources manually in the `metallb-system` namespace:

   ```yaml
   # primary-ip.yaml
   apiVersion: metallb.io/v1beta1
   kind: IPAddressPool
   metadata:
     name: primary-ip-your-namespace
     namespace: metallb-system
   spec:
     addresses:
     - 192.168.123.205/32
     autoAssign: false
   ---
   apiVersion: metallb.io/v1beta1
   kind: L2Advertisement
   metadata:
     name: primary-l2-advert-your-namespace
     namespace: metallb-system
   spec:
     ipAddressPools:
     - primary-ip-your-namespace
   ```

   Apply this with:
   ```bash
   kubectl apply -f primary-ip.yaml
   ```

2. **Use a Separate Chart for MetalLB Resources**: Create a separate chart for MetalLB resources that is installed in the `metallb-system` namespace.

3. **Modify the Admission Webhook**: Configure the MetalLB admission webhook to allow resources in other namespaces (not recommended).

### Load Balancer Services

The chart creates LoadBalancer services that reference the MetalLB address pools:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ingress-primary-api-external
  namespace: your-namespace
  annotations:
    metallb.universe.tf/address-pool: primary-ip-your-namespace
spec:
  type: LoadBalancer
  # ...
```

Make sure the annotation references the correct address pool name.

## Dependency Management

The ingress chart creates the necessary MetalLB resources (IPAddressPool, L2Advertisement) but doesn't install MetalLB itself. This is by design to avoid conflicts with existing MetalLB installations. The chart assumes that MetalLB is already installed in the cluster.

### MetalLB Resources

The chart creates the following MetalLB resources:

1. **IPAddressPool**: Defines the IP addresses that can be assigned to LoadBalancer services
   - Named with the namespace: `primary-ip-{namespace}`
   - Contains the IP address specified in the values file

2. **L2Advertisement**: Advertises the IP addresses to the network using Layer 2 protocol
   - Named with the namespace: `primary-l2-advert-{namespace}`
   - References the corresponding IPAddressPool

### Load Balancer Services

The chart creates LoadBalancer services that use the MetalLB resources:

1. **Primary API Load Balancer**: `{release-name}-primary-api-external`
   - Uses the `primary-ip-{namespace}` address pool
   - Routes traffic to the Ingress Controller

2. **Secondary API Load Balancer**: `{release-name}-secondary-api-external`
   - Uses the `secondary-ip-{namespace}` address pool
   - Routes traffic to the Ingress Controller

3. **Admin Load Balancer**: `{release-name}-admin-lb`
   - Uses the `admin-ip-{namespace}` address pool
   - Routes traffic to the Ingress Controller

## Known Issues

### CRD Ownership

When installing the chart in a cluster where the CRDs are already owned by another release, you may encounter the following error:

```
Error: INSTALLATION FAILED: Unable to continue with install: CustomResourceDefinition "bfdprofiles.metallb.io" in namespace "" exists and cannot be imported into the current release: invalid ownership metadata; annotation validation error: key "meta.helm.sh/release-name" must equal "ingress": current value is "metallb"; annotation validation error: key "meta.helm.sh/release-namespace" must equal "ct-dev": current value is "metallb-system"
```

This happens because Helm tracks ownership of CRDs, and a CRD can only be owned by one release at a time. There are several ways to handle this:

1. **Skip CRD Installation**: Use the `--skip-crds` flag when installing the chart:

   ```bash
   helm install -n ct-dev ingress ./helm/charts/ingress -f ./prod-ingress.yaml --skip-crds
   ```

2. **Disable MetalLB**: If you already have MetalLB installed in the cluster, you can disable it in the chart:

   ```yaml
   # prod-ingress.yaml
   metallb:
     enabled: false
   ```

3. **Use a Different Release Name**: Install the chart with the same release name as the one that owns the CRDs:

   ```bash
   helm install -n metallb-system metallb ./helm/charts/ingress -f ./prod-ingress.yaml
   ```

4. **Delete and Reinstall CRDs**: This is not recommended in production, but for testing you can delete the CRDs and let the chart reinstall them:

   ```bash
   kubectl delete crd bfdprofiles.metallb.io bgpadvertisements.metallb.io bgppeers.metallb.io ipaddresspools.metallb.io l2advertisements.metallb.io communities.metallb.io
   helm install -n ct-dev ingress ./helm/charts/ingress -f ./prod-ingress.yaml
   ```

For production deployments, option 1 or 2 is recommended.
