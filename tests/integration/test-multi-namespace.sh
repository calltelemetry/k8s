#!/bin/bash
# Integration test for multi-namespace deployment of the ingress chart

# Set variables
CHART_DIR="helm/charts/ingress"
DEV_NAMESPACE="test-dev"
PROD_NAMESPACE="test-prod"
DEV_VALUES="test-values.yaml"
PROD_VALUES="prod-ingress.yaml"

# Create test directory if it doesn't exist
mkdir -p tests/integration/output

echo "Starting multi-namespace deployment test..."

# Create namespaces
echo "Creating namespaces: $DEV_NAMESPACE and $PROD_NAMESPACE"
kubectl create namespace $DEV_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $PROD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Render templates for dev namespace
echo "Rendering templates for dev namespace..."
helm template dev-ingress $CHART_DIR --namespace $DEV_NAMESPACE -f $DEV_VALUES > tests/integration/output/dev-install.yaml

# Render templates for prod namespace
echo "Rendering templates for prod namespace..."
helm template prod-ingress $CHART_DIR --namespace $PROD_NAMESPACE -f $PROD_VALUES > tests/integration/output/prod-install.yaml

# Note: We're using 'helm template' instead of 'helm install --dry-run' to avoid CRD ownership issues

# Check if the dev installation contains namespace-aware resource names
echo "Checking dev installation for namespace-aware resource names..."
if grep -q "name: primary-ip-test-dev" tests/integration/output/dev-install.yaml && \
   grep -q "name: primary-l2-advert-test-dev" tests/integration/output/dev-install.yaml; then
  echo "✅ Test passed: Dev installation contains namespace-aware resource names"
else
  echo "❌ Test failed: Dev installation does not contain namespace-aware resource names"
  exit 1
fi

# Check if the prod installation contains namespace-aware resource names
echo "Checking prod installation for namespace-aware resource names..."
if grep -q "name: primary-ip-test-prod" tests/integration/output/prod-install.yaml && \
   grep -q "name: primary-l2-advert-test-prod" tests/integration/output/prod-install.yaml; then
  echo "✅ Test passed: Prod installation contains namespace-aware resource names"
else
  echo "❌ Test failed: Prod installation does not contain namespace-aware resource names"
  exit 1
fi

# Check if the dev installation contains the correct ingress class
echo "Checking dev installation for correct ingress class..."
if grep -q "kubernetes.io/ingress.class: nginx-test" tests/integration/output/dev-install.yaml; then
  echo "✅ Test passed: Dev installation contains correct ingress class"
else
  echo "❌ Test failed: Dev installation does not contain correct ingress class"
  exit 1
fi

# Check if the prod installation contains the correct ingress class
echo "Checking prod installation for correct ingress class..."
if grep -q "kubernetes.io/ingress.class: nginx-prod" tests/integration/output/prod-install.yaml; then
  echo "✅ Test passed: Prod installation contains correct ingress class"
else
  echo "❌ Test failed: Prod installation does not contain correct ingress class"
  exit 1
fi

# Check if the dev and prod installations have different IP addresses
echo "Checking for different IP addresses between dev and prod installations..."
DEV_IP=$(grep -A 10 "name: primary-ip-test-dev" tests/integration/output/dev-install.yaml | grep -A 1 "addresses:" | grep -o "[0-9.]*\/[0-9]*" | head -1)
PROD_IP=$(grep -A 10 "name: primary-ip-test-prod" tests/integration/output/prod-install.yaml | grep -A 1 "addresses:" | grep -o "[0-9.]*\/[0-9]*" | head -1)

echo "Dev IP: $DEV_IP"
echo "Prod IP: $PROD_IP"

if [ "$DEV_IP" != "$PROD_IP" ]; then
  echo "✅ Test passed: Dev and prod installations have different IP addresses"
else
  echo "❌ Test failed: Dev and prod installations have the same IP address"
  exit 1
fi

# Clean up
echo "Cleaning up..."
kubectl delete namespace $DEV_NAMESPACE --ignore-not-found
kubectl delete namespace $PROD_NAMESPACE --ignore-not-found

echo "All tests passed! ✅"
exit 0
