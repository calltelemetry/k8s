#!/bin/bash

# Get the admin load balancer IP
ADMIN_IP=$(kubectl get svc -n test-haproxy ingress-haproxy-admin-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Testing SSH connection to $ADMIN_IP:22..."

# Test TCP connection using netcat
if nc -z -v -w 5 $ADMIN_IP 22; then
    echo "Success! TCP connection to $ADMIN_IP:22 is open."
else
    echo "Failed! Could not establish TCP connection to $ADMIN_IP:22."
fi

# Alternative test using telnet
echo -e "\nTesting with telnet..."
echo "quit" | telnet $ADMIN_IP 22 || echo "Telnet test failed."

# Another alternative using /dev/tcp (Bash built-in)
echo -e "\nTesting with /dev/tcp..."
timeout 5 bash -c "echo > /dev/tcp/$ADMIN_IP/22" && echo "Success! /dev/tcp test passed." || echo "Failed! /dev/tcp test failed."
