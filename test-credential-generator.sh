#!/bin/bash
# Test credential-generator Helm chart in isolation
#
# Usage:
#   ./test-credential-generator.sh [test-namespace]
#
# This script tests:
# 1. Chart rendering (helm template)
# 2. Installation (helm install)
# 3. Secret creation (kubectl verify)
# 4. Idempotency (reinstall, verify no duplicates)
# 5. Cleanup

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_NAMESPACE="${1:-test-credential-gen-$(date +%s)}"
CHARTS_DIR="$(dirname "$0")/helm/charts"
TEST_CHART="$CHARTS_DIR/credential-generator"
RELEASE_NAME="test-release"

log() { echo -e "${BLUE}[*]${NC} $*"; }
pass() { echo -e "${GREEN}[✓]${NC} $*"; }
fail() { echo -e "${RED}[✗]${NC} $*"; exit 1; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }

main() {
  log "Testing credential-generator chart"
  log "Namespace: $TEST_NAMESPACE"
  log "Chart: $TEST_CHART"
  echo ""

  # 1. Verify chart exists
  log "Test 1: Verifying chart structure..."
  [ -f "$TEST_CHART/Chart.yaml" ] || fail "Chart.yaml not found"
  [ -f "$TEST_CHART/values.yaml" ] || fail "values.yaml not found"
  [ -d "$TEST_CHART/templates" ] || fail "templates directory not found"
  pass "Chart structure valid"
  echo ""

  # 2. Test Helm template rendering
  log "Test 2: Rendering Helm templates..."
  helm template "$RELEASE_NAME" "$TEST_CHART" > /tmp/test-manifest.yaml || fail "Helm template failed"
  [ -s /tmp/test-manifest.yaml ] || fail "Rendered manifest is empty"
  grep -q "kind: ServiceAccount" /tmp/test-manifest.yaml || fail "ServiceAccount not in manifest"
  grep -q "kind: Role" /tmp/test-manifest.yaml || fail "Role not in manifest"
  grep -q "kind: RoleBinding" /tmp/test-manifest.yaml || fail "RoleBinding not in manifest"
  grep -q "kind: Job" /tmp/test-manifest.yaml || fail "Job not in manifest"
  pass "All resources present in rendered manifest"
  echo ""

  # 3. Create test namespace
  log "Test 3: Creating test namespace..."
  kubectl create namespace "$TEST_NAMESPACE" || fail "Failed to create namespace"
  pass "Test namespace created: $TEST_NAMESPACE"
  echo ""

  # 4. Install chart
  log "Test 4: Installing credential-generator chart..."
  helm install "$RELEASE_NAME" "$TEST_CHART" \
    -n "$TEST_NAMESPACE" \
    --set enabled=true \
    --set autoGenerate.enabled=true || fail "Helm install failed"
  pass "Chart installed"
  echo ""

  # 5. Wait for Job to complete
  log "Test 5: Waiting for credential-generator Job to complete..."
  local max_attempts=30
  local attempt=0
  while [ $attempt -lt $max_attempts ]; do
    if kubectl get job -n "$TEST_NAMESPACE" "$RELEASE_NAME-credential-generator-job" &>/dev/null; then
      local status=$(kubectl get job -n "$TEST_NAMESPACE" "$RELEASE_NAME-credential-generator-job" -o jsonpath='{.status.succeeded}')
      if [ "$status" = "1" ]; then
        pass "Job completed successfully"
        break
      fi
    fi
    echo -n "."
    sleep 1
    ((attempt++))
  done

  if [ $attempt -eq $max_attempts ]; then
    fail "Job did not complete within timeout"
  fi
  echo ""

  # 6. Verify secrets were created
  log "Test 6: Verifying secrets were created..."
  kubectl get secret postgres-credentials -n "$TEST_NAMESPACE" &>/dev/null || fail "postgres-credentials secret not found"
  kubectl get secret s3-credentials -n "$TEST_NAMESPACE" &>/dev/null || fail "s3-credentials secret not found"
  kubectl get secret nats-credentials -n "$TEST_NAMESPACE" &>/dev/null || fail "nats-credentials secret not found"
  pass "All three secrets created"
  echo ""

  # 7. Verify secret contents
  log "Test 7: Verifying secret contents..."
  local pg_user=$(kubectl get secret postgres-credentials -n "$TEST_NAMESPACE" -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)
  [ -n "$pg_user" ] || fail "POSTGRES_USER is empty"
  pass "POSTGRES_USER: $pg_user"

  local pg_pass=$(kubectl get secret postgres-credentials -n "$TEST_NAMESPACE" -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
  [ ${#pg_pass} -ge 20 ] || fail "POSTGRES_PASSWORD too short (< 20 chars)"
  pass "POSTGRES_PASSWORD generated (${#pg_pass} chars)"

  local s3_user=$(kubectl get secret s3-credentials -n "$TEST_NAMESPACE" -o jsonpath='{.data.S3_ROOT_USER}' | base64 -d)
  [ -n "$s3_user" ] || fail "S3_ROOT_USER is empty"
  pass "S3_ROOT_USER: $s3_user"

  local nats_user=$(kubectl get secret nats-credentials -n "$TEST_NAMESPACE" -o jsonpath='{.data.NATS_USER}' | base64 -d)
  [ -n "$nats_user" ] || fail "NATS_USER is empty"
  pass "NATS_USER: $nats_user"
  echo ""

  # 8. Test idempotency (reinstall, verify no new Job execution)
  log "Test 8: Testing idempotency (reinstalling chart)..."
  sleep 2  # Prevent race condition with previous Job deletion
  helm upgrade "$RELEASE_NAME" "$TEST_CHART" \
    -n "$TEST_NAMESPACE" \
    --set enabled=true \
    --set autoGenerate.enabled=true || fail "Helm upgrade failed"
  pass "Chart upgraded successfully"

  # Verify old secrets still exist with same values
  local pg_pass_after=$(kubectl get secret postgres-credentials -n "$TEST_NAMESPACE" -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
  [ "$pg_pass" = "$pg_pass_after" ] || fail "Password changed after upgrade (idempotency broken)"
  pass "Secrets unchanged after upgrade (idempotent)"
  echo ""

  # 9. Test custom credentials
  log "Test 9: Testing custom credential values..."
  kubectl delete namespace "$TEST_NAMESPACE" || true
  kubectl create namespace "$TEST_NAMESPACE"
  helm install "$RELEASE_NAME" "$TEST_CHART" \
    -n "$TEST_NAMESPACE" \
    --set postgres.username=testuser \
    --set postgres.password=testpass123 \
    --set s3.rootUser=admin \
    --set s3.rootPassword=adminpass || fail "Helm install with custom values failed"

  sleep 5
  local custom_user=$(kubectl get secret postgres-credentials -n "$TEST_NAMESPACE" -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)
  [ "$custom_user" = "testuser" ] || fail "Custom username not applied"
  pass "Custom credentials applied correctly"
  echo ""

  # Cleanup
  log "Cleaning up test resources..."
  kubectl delete namespace "$TEST_NAMESPACE" || true
  pass "Test namespace deleted"
  echo ""

  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}All tests passed!${NC}"
  echo -e "${GREEN}========================================${NC}"
}

main "$@"
