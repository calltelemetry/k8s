#!/bin/bash

# Set namespace
NAMESPACE="test-haproxy"

# Apply the TCP services ConfigMap
echo "Applying TCP services ConfigMap..."
kubectl apply -f haproxy-tcp-configmap.yaml

# Restart the HAProxy pod to pick up the new configuration
echo -e "\nRestarting HAProxy pod..."
kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o name | xargs kubectl delete -n $NAMESPACE

# Wait for the HAProxy pod to be ready
echo -e "\nWaiting for HAProxy pod to be ready..."
sleep 10
kubectl wait --for=condition=Ready pods -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress --timeout=120s

# Get the HAProxy pod name
echo -e "\nGetting HAProxy pod name..."
HAPROXY_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].metadata.name}')
if [ -z "$HAPROXY_POD" ]; then
    echo "Error: Could not get HAProxy pod name"
    exit 1
fi
echo "HAProxy pod: $HAPROXY_POD"

# Check HAProxy configuration
echo -e "\n=== Checking HAProxy Configuration ==="
echo "Checking if HAProxy is configured to forward port 22..."
kubectl exec -n $NAMESPACE $HAPROXY_POD -- cat /etc/haproxy/haproxy.cfg | grep -A 10 "frontend.*:22" || echo "No port 22 configuration found in HAProxy"

# Check TCP services ConfigMap
echo -e "\n=== HAProxy TCP Services ConfigMap ==="
kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress,role=tcp-services -o yaml || echo "Could not get HAProxy TCP Services ConfigMap"

# Get the admin load balancer IP
echo -e "\nGetting admin load balancer IP..."
ADMIN_LB_IP=$(kubectl get svc -n $NAMESPACE ingress-haproxy-admin-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$ADMIN_LB_IP" ]; then
    echo "Error: Could not get admin load balancer IP"
    exit 1
fi
echo "Admin load balancer IP: $ADMIN_LB_IP"

# Test TCP connection to the load balancer
echo -e "\n=== Testing TCP connection to the load balancer ==="
echo "Testing connection to $ADMIN_LB_IP:22..."
nc -z -v -w 5 $ADMIN_LB_IP 22 || echo "Failed to connect to $ADMIN_LB_IP:22"

echo -e "\n=== Summary ==="
echo "1. HAProxy pod: $HAPROXY_POD"
echo "2. Admin load balancer IP: $ADMIN_LB_IP"
echo "3. Check if HAProxy is configured to forward port 22 to the SSH test pod"
echo "4. Try connecting to the SSH server: ssh -p 22 testuser@$ADMIN_LB_IP (password: password)"
