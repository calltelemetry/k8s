#!/bin/bash
# Test script to verify that MetalLB resources are created in the metallb-system namespace
# with namespace-specific names to avoid conflicts

set -e

# Set default values
NAMESPACE="test-namespace"
RELEASE_NAME="test-release"
CHART_DIR="helm/charts/ingress"
VALUES_FILE="test-values.yaml"
OUTPUT_DIR="tests/unit/output"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -n|--namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    -r|--release)
      RELEASE_NAME="$2"
      shift
      shift
      ;;
    -c|--chart)
      CHART_DIR="$2"
      shift
      shift
      ;;
    -f|--values)
      VALUES_FILE="$2"
      shift
      shift
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -n, --namespace NS     Namespace to use for testing (default: test-namespace)"
      echo "  -r, --release NAME     Release name to use for testing (default: test-release)"
      echo "  -c, --chart DIR        Chart directory to test (default: helm/charts/ingress)"
      echo "  -f, --values FILE      Values file to use for testing (default: test-values.yaml)"
      echo "  -o, --output DIR       Output directory for rendered templates (default: tests/unit/output)"
      echo "  -h, --help             Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Render the templates
echo "Rendering templates for namespace: $NAMESPACE"
helm template "$RELEASE_NAME" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --values "$VALUES_FILE" \
  --skip-crds \
  > "$OUTPUT_DIR/metallb-namespace-test.yaml"

# Check if the output file exists
if [ ! -f "$OUTPUT_DIR/metallb-namespace-test.yaml" ]; then
  echo "❌ Test failed: Template rendering failed"
  exit 1
fi

echo "✅ Template rendering successful"

# Test 1: Check if IPAddressPool resources are created in the metallb-system namespace
echo "Test 1: Checking if IPAddressPool resources are created in the metallb-system namespace"
if grep -q "namespace: metallb-system" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "kind: IPAddressPool" "$OUTPUT_DIR/metallb-namespace-test.yaml"; then
  echo "✅ Test passed: IPAddressPool resources are created in the metallb-system namespace"
else
  echo "❌ Test failed: IPAddressPool resources are not created in the metallb-system namespace"
  exit 1
fi

# Test 2: Check if L2Advertisement resources are created in the metallb-system namespace
echo "Test 2: Checking if L2Advertisement resources are created in the metallb-system namespace"
if grep -q "namespace: metallb-system" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "kind: L2Advertisement" "$OUTPUT_DIR/metallb-namespace-test.yaml"; then
  echo "✅ Test passed: L2Advertisement resources are created in the metallb-system namespace"
else
  echo "❌ Test failed: L2Advertisement resources are not created in the metallb-system namespace"
  exit 1
fi

# Test 3: Check if IPAddressPool resources have namespace-specific names
echo "Test 3: Checking if IPAddressPool resources have namespace-specific names"
if grep -q "name: primary-ip-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "name: secondary-ip-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "name: admin-ip-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml"; then
  echo "✅ Test passed: IPAddressPool resources have namespace-specific names"
else
  echo "❌ Test failed: IPAddressPool resources do not have namespace-specific names"
  exit 1
fi

# Test 4: Check if L2Advertisement resources have namespace-specific names
echo "Test 4: Checking if L2Advertisement resources have namespace-specific names"
if grep -q "name: primary-l2-advert-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "name: secondary-l2-advert-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "name: admin-l2-advert-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml"; then
  echo "✅ Test passed: L2Advertisement resources have namespace-specific names"
else
  echo "❌ Test failed: L2Advertisement resources do not have namespace-specific names"
  exit 1
fi

# Test 5: Check if services reference the correct address pools
echo "Test 5: Checking if services reference the correct address pools"
if grep -q "metallb.universe.tf/address-pool: primary-ip-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "metallb.universe.tf/address-pool: secondary-ip-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml" && \
   grep -q "metallb.universe.tf/address-pool: admin-ip-$NAMESPACE" "$OUTPUT_DIR/metallb-namespace-test.yaml"; then
  echo "✅ Test passed: Services reference the correct address pools"
else
  echo "❌ Test failed: Services do not reference the correct address pools"
  exit 1
fi

echo "All tests passed! ✅"
