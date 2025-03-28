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

# Check HAProxy configuration
echo -e "\n=== Checking HAProxy Configuration ==="
echo "Checking if HAProxy is configured to forward port 22..."
kubectl exec -n $NAMESPACE $HAPROXY_POD -- cat /etc/haproxy/haproxy.cfg | grep -A 10 "frontend.*:22" || echo "No port 22 configuration found in HAProxy"

# Test TCP connection to the load balancer
echo -e "\n=== Testing TCP connection to the load balancer ==="
echo "Testing connection to $ADMIN_LB_IP:22..."
nc -z -v -w 5 $ADMIN_LB_IP 22 || echo "Failed to connect to $ADMIN_LB_IP:22"

# Get the SSH test pod IP
echo -e "\nGetting SSH test pod IP..."
SSH_POD_IP=$(kubectl get pod ssh-test-pod -n $NAMESPACE -o jsonpath='{.status.podIP}')
if [ -z "$SSH_POD_IP" ]; then
    echo "Error: Could not get SSH test pod IP"
    exit 1
fi
echo "SSH test pod IP: $SSH_POD_IP"

# Test SSH connection to the SSH test pod directly
echo -e "\n=== Testing SSH connection to the SSH test pod directly ==="
echo "Testing connection to $SSH_POD_IP:2222..."
kubectl run -n $NAMESPACE ssh-client-direct --rm -i --image=alpine -- sh -c "apk add --no-cache openssh-client && echo 'password' | ssh -o StrictHostKeyChecking=no -p 2222 testuser@$SSH_POD_IP 'echo SSH connection successful'" || echo "Failed to connect directly to SSH test pod"

# Test SSH connection to the load balancer
echo -e "\n=== Testing SSH connection to the load balancer ==="
echo "Testing connection to $ADMIN_LB_IP:22..."
kubectl run -n $NAMESPACE ssh-client-lb --rm -i --image=alpine -- sh -c "apk add --no-cache openssh-client && echo 'password' | ssh -o StrictHostKeyChecking=no -p 22 testuser@$ADMIN_LB_IP 'echo SSH connection successful'" || echo "Failed to connect to load balancer"

echo -e "\n=== Summary ==="
echo "1. Admin load balancer IP: $ADMIN_LB_IP"
echo "2. HAProxy pod: $HAPROXY_POD"
echo "3. SSH test pod IP: $SSH_POD_IP"
echo "4. Check if HAProxy is forwarding port 22 to the SSH test pod"
echo "5. Try connecting to the SSH server: ssh -p 22 testuser@$ADMIN_LB_IP (password: password)"
