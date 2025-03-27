#!/bin/bash
# Script to install HAProxy Ingress in multiple namespaces

# Set variables
HAPROXY_CHART="haproxy-ingress/haproxy-ingress"
VALUES_FILE="./haproxy-minimal-values.yaml"

# Function to install HAProxy in a namespace
install_haproxy() {
  NAMESPACE=$1

  echo "Installing HAProxy Ingress in namespace: $NAMESPACE"

  # Create namespace if it doesn't exist
  kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

  # Install HAProxy Ingress with --skip-crds flag to avoid ClusterRole conflicts
  helm install haproxy-ingress $HAPROXY_CHART \
    -n $NAMESPACE \
    -f $VALUES_FILE \
    --skip-crds

  echo "HAProxy Ingress installed in namespace: $NAMESPACE"
}

# Install in first namespace (this will create the ClusterRole)
echo "Installing HAProxy Ingress in the first namespace (haproxy-ingress)"
kubectl create namespace haproxy-ingress --dry-run=client -o yaml | kubectl apply -f -
helm install haproxy-ingress $HAPROXY_CHART -n haproxy-ingress

# Install in additional namespaces
install_haproxy "ct-dev"
install_haproxy "ct-prod"

echo "All installations complete!"
