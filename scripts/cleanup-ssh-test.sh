#!/bin/bash

# Set namespace
NAMESPACE="test-haproxy"

# Delete the SSH test pod and service
echo "Deleting SSH test pod and service..."
kubectl delete -f ssh-test-pod.yaml

# Restore the original HAProxy configuration
echo -e "\nRestoring original HAProxy configuration..."
helm upgrade ingress-haproxy helm/charts/ingress -n $NAMESPACE -f haproxy-values.yaml

echo -e "\nCleanup complete!"
