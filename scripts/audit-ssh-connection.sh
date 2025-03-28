#!/bin/bash

# Set namespace
NAMESPACE="test-haproxy"

# Get the admin load balancer IP
echo "Getting admin load balancer IP..."
ADMIN_LB_IP=$(kubectl get svc -n $NAMESPACE ingress-haproxy-admin-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$ADMIN_LB_IP" ]; then
    echo "Error: Could not get admin load balancer IP"
    exit 1
fi
echo "Admin load balancer IP: $ADMIN_LB_IP"

# Get the HAProxy pod name
echo -e "\nGetting HAProxy pod name..."
HAPROXY_POD=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].metadata.name}')
if [ -z "$HAPROXY_POD" ]; then
    echo "Error: Could not get HAProxy pod name"
    exit 1
fi
echo "HAProxy pod: $HAPROXY_POD"

# Get the admin pod name
echo -e "\nGetting admin pod name..."
ADMIN_POD=$(kubectl get pods -n $NAMESPACE -l app=admin-service -o jsonpath='{.items[0].metadata.name}')
if [ -z "$ADMIN_POD" ]; then
    echo "Error: Could not get admin pod name"
    exit 1
fi
echo "Admin pod: $ADMIN_POD"

# Check HAProxy configuration
echo -e "\n=== Checking HAProxy Configuration ==="
echo "Checking if HAProxy is configured to forward port 22 to admin pod port 3022..."
kubectl exec -n $NAMESPACE $HAPROXY_POD -- cat /etc/haproxy/haproxy.cfg | grep -A 10 "frontend.*:22" || echo "No port 22 configuration found in HAProxy"

# Check if HAProxy is listening on port 22
echo -e "\n=== Checking if HAProxy is listening on port 22 ==="
kubectl exec -n $NAMESPACE $HAPROXY_POD -- netstat -tulpn | grep ":22 " || echo "HAProxy is not listening on port 22"

# Test TCP connection to HAProxy
echo -e "\n=== Testing TCP connection to HAProxy load balancer ==="
echo "Testing connection to $ADMIN_LB_IP:22..."
if nc -z -v -w 5 $ADMIN_LB_IP 22 2>/dev/null; then
    echo "Success! TCP connection to $ADMIN_LB_IP:22 is open."
else
    echo "Failed! Could not establish TCP connection to $ADMIN_LB_IP:22."
fi

# Check if admin pod is listening on port 3022
echo -e "\n=== Checking if admin pod is listening on port 3022 ==="
kubectl exec -n $NAMESPACE $ADMIN_POD -- netstat -tulpn | grep ":3022 " || echo "Admin pod is not listening on port 3022"

# Test direct connection to admin pod on port 3022
echo -e "\n=== Testing direct connection to admin pod on port 3022 ==="
kubectl exec -n $NAMESPACE $HAPROXY_POD -- nc -z -v -w 5 $ADMIN_POD.test-haproxy.svc.cluster.local 3022 2>/dev/null || echo "Failed to connect directly to admin pod on port 3022"

echo -e "\n=== Summary ==="
echo "1. HAProxy load balancer IP: $ADMIN_LB_IP"
echo "2. HAProxy pod: $HAPROXY_POD"
echo "3. Admin pod: $ADMIN_POD"
echo "4. Check the output above to see if HAProxy is forwarding port 22 to port 3022 on the admin pod"
echo "5. Check if the admin pod is listening on port 3022"
