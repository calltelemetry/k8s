#!/bin/bash
# Test script for CallTelemetry Helmfile deployment
# This script verifies that the helmfile works correctly by deploying to a test namespace

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
  echo -e "${2}${1}${NC}"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_message "Checking prerequisites..." "$YELLOW"

if ! command_exists kubectl; then
  print_message "kubectl not found. Please install kubectl first." "$RED"
  exit 1
fi

if ! command_exists helm; then
  print_message "helm not found. Please install Helm first." "$RED"
  exit 1
fi

if ! command_exists helmfile; then
  print_message "helmfile not found. Please install Helmfile first." "$RED"
  exit 1
fi

# Check if connected to a Kubernetes cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
  print_message "Not connected to a Kubernetes cluster. Please configure kubectl." "$RED"
  exit 1
fi

print_message "All prerequisites met." "$GREEN"

# Set namespace for testing
NAMESPACE="ct-test"

# Create test environment file
cat >.env.test.yaml <<EOF
env:
  namespace: ${NAMESPACE}
  environment: test
  domain: test.calltelemetry.com
EOF

print_message "Created test environment file .env.test.yaml" "$GREEN"

# Clean up any previous test deployment
print_message "Cleaning up any previous test deployment..." "$YELLOW"
helmfile --environment test destroy || true
kubectl delete namespace ${NAMESPACE} --ignore-not-found

# Run helmfile with test environment
print_message "Deploying CallTelemetry to test namespace ${NAMESPACE}..." "$YELLOW"
helmfile --environment test -f helmfile.yaml -e .env.test.yaml apply

# Check deployment status
print_message "Checking deployment status..." "$YELLOW"
kubectl get pods -n ${NAMESPACE}

# Test the deployment
print_message "Testing the deployment..." "$YELLOW"

# Wait for HAProxy to be ready
print_message "Waiting for HAProxy to be ready..." "$YELLOW"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=haproxy-ingress -n ${NAMESPACE} --timeout=300s

# Get HAProxy service IP
HAPROXY_IP=$(kubectl get svc -n ${NAMESPACE} -l app.kubernetes.io/name=haproxy-ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

if [ -z "$HAPROXY_IP" ]; then
  print_message "Could not get HAProxy IP. Using localhost for testing." "$YELLOW"
  HAPROXY_IP="localhost"
fi

# Test API endpoint
print_message "Testing API endpoint..." "$YELLOW"
if curl -s -H "Host: test.calltelemetry.com" http://${HAPROXY_IP}/api/health | grep -q "ok"; then
  print_message "API endpoint test passed." "$GREEN"
else
  print_message "API endpoint test failed." "$RED"
fi

# Test Vue Web endpoint
print_message "Testing Vue Web endpoint..." "$YELLOW"
if curl -s -H "Host: test.calltelemetry.com" http://${HAPROXY_IP}/ | grep -q "CallTelemetry"; then
  print_message "Vue Web endpoint test passed." "$GREEN"
else
  print_message "Vue Web endpoint test failed." "$RED"
fi

print_message "Test completed." "$GREEN"
print_message "To clean up the test deployment, run: helmfile --environment test destroy" "$YELLOW"
