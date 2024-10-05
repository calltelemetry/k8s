# Call Telemetry Kubernetes Charts

Kubernetes helm charts and support tools.

## Getting started with Call Telemetry and helm

```sh
> helm repo add ct-charts https://calltelemetry.github.io/k8s/helm/charts/
> helm repo update

> helm repo list
NAME          	URL
ct-charts          	https://calltelemetry.github.io/k8s/helm/charts/

> helm install -n ct ct-charts/ingress
> helm install -n ct ct-charts/api
> helm install -n ct ct-charts/vue
```
bump
