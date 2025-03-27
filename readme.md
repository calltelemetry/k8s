# Call Telemetry Kubernetes Charts

Kubernetes helm charts and support tools.

## Repository Structure

```
.
├── helm/
│   ├── charts/
│   │   ├── api/             # API service chart
│   │   ├── echo/            # Echo server chart
│   │   ├── ingress/         # Ingress controller chart
│   │   ├── teams-auth/      # Teams authentication chart
│   │   └── vue-web/         # Vue web frontend chart
├── index.yaml               # Helm repository index file
├── update-helm-repo.sh      # Script to update the Helm repository
├── architecture-diagram.md  # High-level architecture diagram
├── detailed-architecture-diagram.md  # Detailed architecture diagram
├── kubernetes-resources-diagram.md   # Kubernetes resources diagram
├── helm-chart-tdd.md        # Test-Driven Development approach for Helm charts
└── tests/                   # Test scripts for Helm charts
    ├── unit/                # Unit tests for Helm charts
    └── integration/         # Integration tests for Helm charts
```

## Architecture

The architecture consists of:

1. **MetalLB Layer 2 Load Balancers**:
   - Primary API Load Balancer
   - Secondary API Load Balancer
   - Admin Load Balancer

2. **Nginx Ingress Controllers**:
   - These receive traffic from the load balancers

3. **Ingress Resources**:
   - API Ingress (routes to API services)
   - Admin Ingress (routes to Admin services)
   - Vue-Web Ingress (routes to frontend)

4. **Services**:
   - Curri API Service
   - Admin Service
   - Traceroute Service
   - Vue-Web Service

5. **Deployments/Pods**:
   - API Worker Pods
   - Admin Pods
   - Traceroute Pods
   - Vue-Web Pods

For more detailed diagrams, see:
- [Architecture Diagram](architecture-diagram.md)
- [Detailed Architecture Diagram](detailed-architecture-diagram.md)
- [Kubernetes Resources Diagram](kubernetes-resources-diagram.md)
- [Helm Chart TDD](helm-chart-tdd.md)

## MetalLB Integration

The ingress chart integrates with MetalLB to provide external IP addresses for LoadBalancer services. This integration has been designed to work with MetalLB's admission webhook, which requires that IPAddressPool and L2Advertisement resources be created in the `metallb-system` namespace.

### Key Features

1. **Namespace-Specific Resources**: The chart creates MetalLB resources in the `metallb-system` namespace with namespace-specific names to avoid conflicts.
2. **Multi-Namespace Support**: The chart can be installed in multiple namespaces without conflicts.
3. **Skip CRDs Flag**: When installing the chart in a cluster with MetalLB already installed, use the `--skip-crds` flag to avoid CRD ownership conflicts.

### Installation with MetalLB

```sh
# Install MetalLB first (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

# Install the ingress chart with the --skip-crds flag
helm install -n your-namespace ingress ./helm/charts/ingress -f ./your-values.yaml --skip-crds
```

For more details, see the [Detailed Architecture Diagram](detailed-architecture-diagram.md).

## Test-Driven Development

This repository follows a test-driven development (TDD) approach for Helm charts. The `tests/` directory contains unit and integration tests for the charts.

### Running Tests

```sh
# Run unit tests for the MetalLB namespace integration
./tests/unit/test-metallb-namespace.sh -f ./your-values.yaml

# Run integration tests for multi-namespace deployment
./tests/integration/test-multi-namespace.sh
```

For more details on the TDD approach, see the [Helm Chart TDD](helm-chart-tdd.md) document.

## Getting started with Call Telemetry and helm

```sh
> helm repo add ct-charts https://calltelemetry.github.io/k8s/helm
> helm repo update

> helm repo list
NAME          	URL
ct-charts          	https://calltelemetry.github.io/k8s/helm

> helm install -n ct ct-charts/ingress
> helm install -n ct ct-charts/api
> helm install -n ct ct-charts/vue-web
```

## Automated Chart Versioning and Publishing

This repository includes a production-ready GitHub Actions workflow that automatically:

1. **Detects Changes**: Precisely identifies which charts have been modified in each commit
2. **Semantic Versioning**: Automatically increments the patch version of modified charts following semver principles
3. **Dependency Management**: Updates chart dependencies before packaging
4. **Packages Charts**: Creates .tgz packages for all charts
5. **Updates Index**: Regenerates the index.yaml file with the new chart versions
6. **Publishes**: Commits and pushes all changes to the repository

The workflow runs whenever changes are pushed to the main branch and affect files in the `helm/charts/` directory. This ensures your chart versions are always properly incremented when changes are made, and the repository index is kept up-to-date.

### How It Works

When you push changes to any chart in the `helm/charts/` directory:

1. The workflow detects exactly which charts were modified
2. For each modified chart, it increments the patch version (e.g., 0.11.4 → 0.11.5)
3. It commits these version changes first
4. Then it packages all charts (with updated dependencies)
5. Finally, it updates the index.yaml file and pushes the packaged charts

This approach ensures proper versioning and maintains a clean Git history.

## Setting Up GitHub Pages as a Helm Repository

### 1. Enable GitHub Pages

1. Go to your GitHub repository settings
2. Scroll down to the "GitHub Pages" section
3. Select the branch you want to publish from (usually `main` or `master`)
4. Select the root directory as the source
5. Click "Save"

GitHub will provide you with a URL for your GitHub Pages site (e.g., `https://username.github.io/repo-name`).

### 2. Update Configuration

1. The `update-helm-repo.sh` script is already configured with the correct GitHub Pages URL:

```bash
REPO_URL="https://calltelemetry.github.io/k8s/helm"
```

### 3. Package Charts and Update Index

1. Make the script executable:

```bash
chmod +x update-helm-repo.sh
```

2. Run the script to package your charts and update the index.yaml file:

```bash
./update-helm-repo.sh
```

3. Commit and push the changes to your GitHub repository:

```bash
git add .
git commit -m "Update Helm repository"
git push
```

### 4. Using the Helm Repository

Once your GitHub Pages site is set up and the index.yaml file is available, you can add the repository to Helm:

```bash
helm repo add ct-charts https://calltelemetry.github.io/k8s/helm
helm repo update
```

Then you can install charts from your repository:

```bash
helm install my-release ct-charts/chart-name
```

## Manually Creating/Updating the Helm Repository

If you prefer to manually update the repository:

1. Package each chart:

```bash
helm package helm/charts/api -d .
helm package helm/charts/echo -d .
helm package helm/charts/ingress -d .
helm package helm/charts/teams-auth -d .
helm package helm/charts/vue-web -d .
```

2. Update the index.yaml file:

```bash
helm repo index . --url https://calltelemetry.github.io/k8s/helm
```

3. Commit and push the changes to your GitHub repository.
