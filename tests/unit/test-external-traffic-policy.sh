#!/bin/bash
# Unit test for admin/primary/secondary_api.externalTrafficPolicy in the
# ingress chart (REL-948 / ct-meta ADR 0613, ADR 0628).
#
# Guards two things:
#   1. The default stays "Cluster" with no override — every existing
#      HelmRelease in ct-infrastructure renders byte-identical LB Services
#      until it explicitly opts in.
#   2. Setting *_api.externalTrafficPolicy: Local actually flows through to
#      the rendered Service, since that is the whole point of the value.

set -e

CHART_DIR="helm/charts/ingress"
RELEASE_NAME="test-release"
NAMESPACE="test-ns"

mkdir -p tests/unit/output

echo "Rendering with no externalTrafficPolicy override (expect Cluster on all three LBs)..."
helm template "$RELEASE_NAME" "$CHART_DIR" --namespace "$NAMESPACE" \
  --set primary_api.createLoadBalancer=true \
  --set secondary_api.createLoadBalancer=true \
  > tests/unit/output/etp-default.yaml

for svc in admin primary-api secondary-api; do
  if ! awk "/name: ${RELEASE_NAME}-${svc}/,/^---/" tests/unit/output/etp-default.yaml \
       | grep -q "externalTrafficPolicy: Cluster"; then
    echo "FAILED: expected externalTrafficPolicy: Cluster by default on ${svc} Service" >&2
    exit 1
  fi
done
echo "PASSED: default externalTrafficPolicy is Cluster on all three LB Services"

echo "Rendering with admin_api.externalTrafficPolicy=Local..."
helm template "$RELEASE_NAME" "$CHART_DIR" --namespace "$NAMESPACE" \
  --set admin_api.externalTrafficPolicy=Local \
  --show-only templates/admin-load-balancer.yaml \
  > tests/unit/output/etp-admin-local.yaml

if ! grep -q "externalTrafficPolicy: Local" tests/unit/output/etp-admin-local.yaml; then
  echo "FAILED: admin_api.externalTrafficPolicy=Local did not reach the rendered Service" >&2
  exit 1
fi
echo "PASSED: admin_api.externalTrafficPolicy=Local flows through to the admin LB Service"

exit 0
