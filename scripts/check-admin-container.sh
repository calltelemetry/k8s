#!/bin/bash

# Set namespace
NAMESPACE="test-haproxy"

# Get the admin pod name
echo "Getting admin pod name..."
ADMIN_POD=$(kubectl get pods -n $NAMESPACE -l app=admin-service -o jsonpath='{.items[0].metadata.name}')
if [ -z "$ADMIN_POD" ]; then
    echo "Error: Could not get admin pod name"
    exit 1
fi
echo "Admin pod: $ADMIN_POD"

# Check if the admin container has port 3022 exposed
echo -e "\n=== Checking admin container ports ==="
kubectl get pod $ADMIN_POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].ports[*].containerPort}' | tr ' ' '\n' | grep 3022 || echo "Port 3022 is not exposed in the admin container"

# Check if any process is listening on port 3022
echo -e "\n=== Checking if any process is listening on port 3022 ==="
kubectl exec -n $NAMESPACE $ADMIN_POD -- sh -c "ls -la /proc/*/fd/* 2>/dev/null | grep socket | xargs grep -l 3022 2>/dev/null" || echo "No process is listening on port 3022"

# Check if SSH server is installed
echo -e "\n=== Checking if SSH server is installed ==="
kubectl exec -n $NAMESPACE $ADMIN_POD -- which sshd || echo "SSH server (sshd) is not installed"

# Check if SSH server is running
echo -e "\n=== Checking if SSH server is running ==="
kubectl exec -n $NAMESPACE $ADMIN_POD -- ps aux | grep sshd | grep -v grep || echo "SSH server (sshd) is not running"

echo -e "\n=== Summary ==="
echo "1. Admin pod: $ADMIN_POD"
echo "2. Check if port 3022 is exposed in the admin container"
echo "3. Check if any process is listening on port 3022"
echo "4. Check if SSH server is installed"
echo "5. Check if SSH server is running"
echo -e "\nIf SSH server is not installed or not running, you may need to install and configure it in the admin container."
