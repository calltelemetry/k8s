# HAProxy Multi-Namespace Architecture with Shared RBAC

## Problem Statement

When deploying HAProxy ingress controller in multiple namespaces, we encounter a conflict with cluster-wide RBAC resources. The issue arises because:

1. HAProxy ingress requires cluster-wide permissions via ClusterRole
2. Helm tracks ownership of cluster-wide resources
3. A ClusterRole can only be owned by one Helm release
4. Installing HAProxy in a second namespace fails due to ClusterRole ownership conflict

## Solution Architecture

### 1. Shared RBAC Resources

Instead of letting each HAProxy installation create its own RBAC resources, we create a single shared set of RBAC resources:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: haproxy-cluster-role-devops
rules:
- apiGroups: [""]
  resources:
  - configmaps
  - secrets
  - endpoints
  - nodes
  - pods
  - services
  - namespaces
  - events
  - serviceaccounts
  verbs:
  - get
  - list
  - watch
  - create
  - patch
  - update
- apiGroups: ["coordination.k8s.io"]
  resources:
  - leases
  verbs:
  - get
  - list
  - watch
  - create
  - update
  - patch
  - delete
```

### 2. Per-Namespace ServiceAccounts and ClusterRoleBindings

For each namespace where HAProxy is installed:
1. Create a ServiceAccount in that namespace
2. Create a ClusterRoleBinding that binds the shared ClusterRole to the namespace's ServiceAccount

Example for ct-dev namespace:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: haproxy-ingress
  namespace: ct-dev
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: haproxy-ingress-crb-ct-dev
subjects:
- kind: ServiceAccount
  name: haproxy-ingress
  namespace: ct-dev
roleRef:
  kind: ClusterRole
  name: haproxy-cluster-role-devops
  apiGroup: rbac.authorization.k8s.io
```

### 3. HAProxy Configuration

Each HAProxy installation is configured to:
1. Disable RBAC creation (since we're using shared resources)
2. Use the existing ServiceAccount
3. Use namespace-specific IngressClass

Example values for ct-dev:
```yaml
# Disable RBAC creation - using shared RBAC resources
rbac:
  create: false

# Use existing ServiceAccount
serviceAccount:
  create: false
  name: "haproxy-ingress"

# Controller configuration
controller:
  ingressClassResource:
    enabled: true
    name: haproxy-ct-dev
    default: false
    controllerValue: "haproxy.io/ingress-ct-dev"
```

## Benefits

1. **No Resource Conflicts**: By using a shared ClusterRole, we avoid Helm ownership conflicts
2. **Clear Separation**: Each namespace has its own ServiceAccount and ClusterRoleBinding
3. **Simplified Management**: RBAC resources are managed independently of HAProxy installations
4. **Better Security**: Explicit control over cluster-wide permissions
5. **Scalable**: Easy to add new HAProxy instances in additional namespaces

## Implementation Steps

1. Create a YAML file with the shared RBAC resources:
   ```yaml
   # haproxy-shared-rbac.yaml
   ---
   # Shared ClusterRole
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRole
   metadata:
     name: haproxy-cluster-role-devops
   rules:
   - apiGroups: [""]
     resources: ["configmaps", "secrets", "endpoints", "nodes", "pods", "services", "namespaces", "events", "serviceaccounts"]
     verbs: ["get", "list", "watch", "create", "patch", "update"]
   - apiGroups: ["coordination.k8s.io"]
     resources: ["leases"]
     verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

   ---
   # ServiceAccount for ct-dev namespace
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: haproxy-ingress
     namespace: ct-dev

   ---
   # ClusterRoleBinding for ct-dev namespace
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRoleBinding
   metadata:
     name: haproxy-ingress-crb-ct-dev
   subjects:
   - kind: ServiceAccount
     name: haproxy-ingress
     namespace: ct-dev
   roleRef:
     kind: ClusterRole
     name: haproxy-cluster-role-devops
     apiGroup: rbac.authorization.k8s.io

   ---
   # ServiceAccount for ct-prod namespace
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: haproxy-ingress
     namespace: ct-prod

   ---
   # ClusterRoleBinding for ct-prod namespace
   apiVersion: rbac.authorization.k8s.io/v1
   kind: ClusterRoleBinding
   metadata:
     name: haproxy-ingress-crb-ct-prod
   subjects:
   - kind: ServiceAccount
     name: haproxy-ingress
     namespace: ct-prod
   roleRef:
     kind: ClusterRole
     name: haproxy-cluster-role-devops
     apiGroup: rbac.authorization.k8s.io
   ```

2. Apply the RBAC resources:
   ```bash
   kubectl apply -f haproxy-shared-rbac.yaml
   ```

3. Create values files for each namespace:
   ```yaml
   # haproxy-ct-dev-values.yaml
   rbac:
     create: false

   serviceAccount:
     create: false
     name: "haproxy-ingress"

   controller:
     ingressClassResource:
       enabled: true
       name: haproxy-ct-dev
       default: false
       controllerValue: "haproxy.io/ingress-ct-dev"
   ```

4. Install HAProxy in each namespace:
   ```bash
   helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-dev -f haproxy-ct-dev-values.yaml
   helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-prod -f haproxy-ct-prod-values.yaml
   ```

## Lessons Learned

1. **ServiceAccount Timing**: The ServiceAccount must exist before installing HAProxy
2. **ClusterRoleBinding vs RoleBinding**: We used ClusterRoleBinding instead of RoleBinding because HAProxy needs cluster-wide permissions
3. **Coordination API**: HAProxy needs access to the coordination.k8s.io API for leader election
4. **Deployment Restart**: If the ServiceAccount is created after the deployment, you may need to restart the deployment:
   ```bash
   kubectl rollout restart deployment -n ct-prod haproxy-ingress
   ```

## Troubleshooting

Common issues and solutions:

1. **ServiceAccount Not Found**: If you see an error like `error looking up service account ct-prod/haproxy-ingress: serviceaccount "haproxy-ingress" not found`, make sure the ServiceAccount exists in the namespace:
   ```bash
   kubectl get serviceaccount -n ct-prod haproxy-ingress
   ```
   If it doesn't exist, apply the RBAC resources again:
   ```bash
   kubectl apply -f haproxy-shared-rbac.yaml
   ```

2. **Permission Denied**: If you see permission denied errors in the HAProxy logs, check that the ClusterRoleBinding is correctly set up:
   ```bash
   kubectl get clusterrolebinding haproxy-ingress-crb-ct-prod -o yaml
   ```
   Make sure it references the correct ServiceAccount and ClusterRole.

3. **IngressClass Conflict**: If you see an error about IngressClass ownership, you may need to delete and recreate the IngressClass:
   ```bash
   kubectl delete ingressclass haproxy-ct-prod
   ```
   Then reinstall HAProxy.

## Security Considerations

1. The shared ClusterRole has significant permissions - review and restrict as needed
2. Each namespace's ServiceAccount only gets permissions via ClusterRoleBinding
3. Consider using NetworkPolicies to restrict cross-namespace traffic
4. Regularly audit RBAC permissions and remove unused ones
