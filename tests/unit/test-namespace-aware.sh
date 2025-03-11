#!/bin/bash
# Unit test for namespace-aware resources in the ingress chart

# Set variables
CHART_DIR="helm/charts/ingress"
RELEASE_NAME="test-release"
NAMESPACE="test-ns"
VALUES_FILE="test-values.yaml"

# Create test directory if it doesn't exist
mkdir -p tests/unit/output

# Render the template
echo "Rendering templates with namespace: $NAMESPACE"
helm template $RELEASE_NAME $CHART_DIR --namespace $NAMESPACE -f $VALUES_FILE > tests/unit/output/rendered-templates.yaml

# Check if the rendered output contains namespace-aware resource names
echo "Checking for namespace-aware resource names..."

# Check IPAddressPool resources
if grep -q "name: primary-ip-$NAMESPACE" tests/unit/output/rendered-templates.yaml; then
  echo "✅ Test passed: IPAddressPool name includes namespace"
else
  echo "❌ Test failed: IPAddressPool name does not include namespace"
  exit 1
fi

# Check L2Advertisement resources
if grep -q "name: primary-l2-advert-$NAMESPACE" tests/unit/output/rendered-templates.yaml; then
  echo "✅ Test passed: L2Advertisement name includes namespace"
else
  echo "❌ Test failed: L2Advertisement name does not include namespace"
  exit 1
fi

# Check if the rendered output contains custom annotations
echo "Checking for custom annotations..."
if grep -q "custom.annotation/example" tests/unit/output/rendered-templates.yaml; then
  echo "✅ Test passed: Output contains custom annotations"
else
  echo "❌ Test failed: Output does not contain custom annotations"
  exit 1
fi

# Check if the rendered output contains the correct ingress class
echo "Checking for correct ingress class..."
if grep -q "kubernetes.io/ingress.class: nginx-test" tests/unit/output/rendered-templates.yaml; then
  echo "✅ Test passed: Output contains correct ingress class"
else
  echo "❌ Test failed: Output does not contain correct ingress class"
  exit 1
fi

# Since we've moved away from IngressClass to annotations, we'll check for the annotations instead
echo "Checking for correct ingress annotations..."
if grep -q "kubernetes.io/ingress.class: nginx-test" tests/unit/output/rendered-templates.yaml; then
  echo "✅ Test passed: Output contains correct ingress class annotations"
else
  echo "❌ Test failed: Output does not contain correct ingress class annotations"
  exit 1
fi

echo "All tests passed! ✅"
exit 0
