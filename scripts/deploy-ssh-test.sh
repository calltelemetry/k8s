#!/bin/bash

# Set namespace
NAMESPACE="test-haproxy"

# Deploy the SSH test pod
echo "Deploying SSH test pod..."
kubectl apply -f ssh-test-pod.yaml

# Wait for the pod to be ready
echo -e "\nWaiting for SSH test pod to be ready..."
kubectl wait --for=condition=Ready pod/ssh-test-pod -n $NAMESPACE --timeout=120s

# Get the pod IP
echo -e "\nGetting SSH test pod IP..."
POD_IP=$(kubectl get pod ssh-test-pod -n $NAMESPACE -o jsonpath='{.status.podIP}')
if [ -z "$POD_IP" ]; then
    echo "Error: Could not get SSH test pod IP"
    exit 1
fi
echo "SSH test pod IP: $POD_IP"

# Check if the pod is listening on port 2222
echo -e "\n=== Checking if SSH test pod is listening on port 2222 ==="
kubectl exec -n $NAMESPACE ssh-test-pod -- sh -c "ps aux | grep sshd" || echo "SSH server (sshd) is not running"

# Test SSH connection from another pod
echo -e "\n=== Testing SSH connection from another pod ==="
echo "Creating a temporary test pod..."
kubectl run -n $NAMESPACE ssh-client --rm -i --image=alpine -- sh -c "apk add --no-cache openssh-client && echo 'password' | ssh -o StrictHostKeyChecking=no -p 2222 testuser@$POD_IP 'echo SSH connection successful'"

# Create and apply the HAProxy TCP services ConfigMap
echo -e "\n=== Creating HAProxy TCP services ConfigMap ==="
kubectl apply -f haproxy-tcp-configmap.yaml

# Upgrade HAProxy ingress controller with TCP services configuration
echo -e "\nUpgrading HAProxy ingress controller..."
helm upgrade ingress-haproxy helm/charts/ingress -n $NAMESPACE -f haproxy-values.yaml --set-string controller.extraArgs.tcp-services-configmap=test-haproxy/haproxy-tcp-services

# Wait for HAProxy to be ready
echo -e "\nWaiting for HAProxy to be ready..."
sleep 10

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

# Get the admin load balancer IP
echo -e "\nGetting admin load balancer IP..."
ADMIN_LB_IP=$(kubectl get svc -n $NAMESPACE ingress-haproxy-admin-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$ADMIN_LB_IP" ]; then
    echo "Error: Could not get admin load balancer IP"
    exit 1
fi
echo "Admin load balancer IP: $ADMIN_LB_IP"

# Test SSH connection to the load balancer
echo -e "\n=== Testing SSH connection to the load balancer ==="
echo "Testing connection to $ADMIN_LB_IP:22..."
nc -z -v -w 5 $ADMIN_LB_IP 22 || echo "Failed to connect to $ADMIN_LB_IP:22"

echo -e "\n=== Summary ==="
echo "1. SSH test pod IP: $POD_IP"
echo "2. Admin load balancer IP: $ADMIN_LB_IP"
echo "3. Check if HAProxy is forwarding port 22 to the SSH test pod"
echo "4. Try connecting to the SSH server: ssh -p 22 testuser@$ADMIN_LB_IP (password: password)"
