# DigitalOcean stable and beta channels

`helmfile-channels.yaml` contains only namespaced application releases for the
shared DigitalOcean cluster. It intentionally does not install cluster-scoped
operators, PostgreSQL, ingress controllers, LoadBalancers, or observability.

The release workflow supplies the repository, tag, and digest variables for
the web and Vue images from the immutable release manifest. All six image
variables are required by the post-renderer. The namespace-specific database
secret is created by the protected bootstrap workflow and is never generated
by an automatic release deployment.

Automatic deployments use Helm's ConfigMap storage driver. This keeps Helm
release history namespace-scoped without granting the deployer permission to
delete the bootstrap-managed `api-db-secret`.

The deployer roles have no Secret-object permissions. The application charts
reference the bootstrap-managed database Secret at runtime, while only the
protected bootstrap workflow can create or rotate its contents. Preventing a
workload creator from referencing an existing Secret by Pod-spec fields would
require a cluster admission policy, which is intentionally outside this
namespace-only overlay.

Each channel's NATS JetStream state uses a 5Gi namespaced PVC so Pod
replacement does not discard streams, KV buckets, or object-store data.

The overlay uses a Helm 3 post-renderer to omit the API chart's default
database Secret object, strip the web chart's duplicate cert-manager
annotation, and enforce image digests; the workflow pins Helm 3.16.4.

Traceroute retains the reviewed chart's root runtime because the published
image performs network diagnostic operations that require its existing runtime
assumptions; changing its UID is outside this channel-overlay change.
