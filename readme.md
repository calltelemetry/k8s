# Call Telemetry Kubernetes Charts

Kubernetes helm charts and support tools.

## Getting started with Call Telemetry and helm

```sh
> helm repo add nats https://calltelemetry.github.io/k8s/helm/charts/
> helm repo update

> helm repo list
NAME          	URL
nats          	https://nats-io.github.io/k8s/helm/charts/

> helm install my-nats nats/nats
```
