# Teams Azure Auth Service Helm Chart

This Helm chart deploys the Teams Azure Auth Service, which provides authentication endpoints for Microsoft Teams integration.

## Features

- Dynamic credential management using NATS Key-Value store
- Organization-specific credentials (clientId, clientSecret, tenantId)
- Configurable logging and debugging

## Prerequisites

- Kubernetes 1.16+
- Helm 3.0+
- NATS server with JetStream enabled

## Installing the Chart

```bash
helm install teams-auth ./helm/charts/teams-auth
```

## Configuration

The following table lists the configurable parameters of the Teams Azure Auth Service chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `yourimage` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Kubernetes service port | `80` |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts | `[]` |
| `ingress.tls` | Ingress TLS configuration | `[]` |
| `nats.url` | NATS server URL | `nats://nats-server:4222` |
| `nats.credentialsBucket` | NATS KV bucket for credentials | `credentials` |
| `port` | Server port | `3000` |
| `debugLevel` | Logging level | `info` |

## NATS Configuration

The Teams Azure Auth Service uses NATS with JetStream for dynamic credential management. Ensure your NATS server has JetStream enabled:

```yaml
# Example NATS configuration
jetstream:
  enabled: true
  memStorage:
    enabled: true
    size: 1Gi
  fileStorage:
    enabled: true
    size: 10Gi
```

## Credential Management

The service uses a NATS Key-Value store for credential management. Credentials are stored with keys in the format `org:{orgId}` and values as JSON with the following structure:

```json
{
  "clientId": "...",
  "clientSecret": "...",
  "tenantId": "...",
  "redirectUri": "..."
}
```

These credentials are managed exclusively through the API and pushed into the NATS KV store.

## Authentication Flow

1. **Initiate Auth**: `GET /auth?orgId=123&redirectUri=https://your-app.com/callback`
2. **Handle Callback**: `GET /callback` (Microsoft redirects here with auth code)
3. **Renew Token**: `GET /renew?orgId=123&refresh_token=xyz`
