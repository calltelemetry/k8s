#!/bin/bash

# Set namespace
NAMESPACE="test-haproxy"

# Get the HAProxy pod name
echo "Getting HAProxy pod name..."
HAPROXY_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].metadata.name}')
if [ -z "$HAPROXY_POD" ]; then
    echo "Error: Could not get HAProxy pod name"
    exit 1
fi
echo "HAProxy pod: $HAPROXY_POD"

# Check HAProxy version
echo -e "\n=== HAProxy Version ==="
kubectl exec -n $NAMESPACE $HAPROXY_POD -- haproxy -v || echo "Could not get HAProxy version"

# Check HAProxy process
echo -e "\n=== HAProxy Process ==="
kubectl exec -n $NAMESPACE $HAPROXY_POD -- ps aux | grep haproxy || echo "HAProxy process not found"

# Check HAProxy configuration file
echo -e "\n=== HAProxy Configuration File ==="
kubectl exec -n $NAMESPACE $HAPROXY_POD -- cat /etc/haproxy/haproxy.cfg || echo "Could not get HAProxy configuration"

# Check if HAProxy is listening on port 22
echo -e "\n=== Checking if HAProxy is listening on port 22 ==="
kubectl exec -n $NAMESPACE $HAPROXY_POD -- ss -tulpn | grep ":22 " || echo "HAProxy is not listening on port 22"

# Check HAProxy logs
echo -e "\n=== HAProxy Logs ==="
kubectl logs -n $NAMESPACE $HAPROXY_POD | tail -n 50 || echo "Could not get HAProxy logs"

# Check ConfigMap
echo -e "\n=== HAProxy ConfigMap ==="
kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o yaml || echo "Could not get HAProxy ConfigMap"

# Check TCP services ConfigMap
echo -e "\n=== HAProxy TCP Services ConfigMap ==="
kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress,role=tcp-services -o yaml || echo "Could not get HAProxy TCP Services ConfigMap"

echo -e "\n=== Summary ==="
echo "1. HAProxy pod: $HAPROXY_POD"
echo "2. Check if HAProxy is configured to forward port 22"
echo "3. Check if HAProxy is listening on port 22"
echo "4. Check HAProxy logs for any errors related to TCP services"
