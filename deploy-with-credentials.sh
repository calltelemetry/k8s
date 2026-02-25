#!/bin/bash
# Deploy CallTelemetry infrastructure with auto-generated credentials
#
# Usage:
#   ./deploy-with-credentials.sh [namespace] [release-name]
#
# Examples:
#   ./deploy-with-credentials.sh ct-dev my-release          # Dev deployment
#   ./deploy-with-credentials.sh ct-prod prod --values prod-values.yaml
#
# The credential-generator chart must be installed FIRST.
# It creates secrets that other services reference.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${1:-ct-dev}"
RELEASE_NAME="${2:-calltelemetry}"
CHARTS_DIR="$(dirname "$0")/helm/charts"
VERBOSITY="${VERBOSITY:-0}"

# Functions
log() {
  echo -e "${BLUE}[*]${NC} $*"
}

success() {
  echo -e "${GREEN}[✓]${NC} $*"
}

warning() {
  echo -e "${YELLOW}[!]${NC} $*"
}

error() {
  echo -e "${RED}[✗]${NC} $*"
}

verify_kubernetes() {
  log "Verifying Kubernetes connectivity..."
  if ! kubectl cluster-info &>/dev/null; then
    error "Cannot connect to Kubernetes cluster"
    exit 1
  fi
  success "Connected to Kubernetes cluster"
}

create_namespace() {
  log "Creating namespace: $NAMESPACE"
  if kubectl get namespace "$NAMESPACE" &>/dev/null; then
    warning "Namespace $NAMESPACE already exists"
  else
    kubectl create namespace "$NAMESPACE"
    success "Created namespace $NAMESPACE"
  fi
}

install_chart() {
  local chart=$1
  local release=$2
  local namespace=$3
  shift 3
  local extra_args=("$@")

  log "Installing $chart (release: $release)..."

  if ! helm list -n "$namespace" | grep -q "^$release"; then
    helm install "$release" "$CHARTS_DIR/$chart" \
      -n "$namespace" \
      "${extra_args[@]}"
    success "Installed $chart"
  else
    warning "$chart already installed, skipping"
  fi
}

main() {
  log "CallTelemetry Infrastructure Deployment"
  log "Namespace: $NAMESPACE"
  log "Release Name: $RELEASE_NAME"
  echo ""

  verify_kubernetes
  create_namespace
  echo ""

  # Install credential-generator FIRST
  log "Installing credential-generator (creates secrets)..."
  install_chart "credential-generator" "credential-generator" "$NAMESPACE" \
    --set enabled=true \
    --set autoGenerate.enabled=true
  echo ""

  # Install infrastructure services
  log "Installing infrastructure services..."
  echo ""

  install_chart "postgresql" "postgresql" "$NAMESPACE" \
    --set existingSecret="postgres-credentials"
  success "PostgreSQL installed"
  echo ""

  install_chart "seaweedfs" "seaweedfs" "$NAMESPACE" \
    --set auth.existingSecret="s3-credentials"
  success "SeaweedFS installed"
  echo ""

  install_chart "nats" "nats" "$NAMESPACE"
  success "NATS installed"
  echo ""

  # Verification
  log "Verifying deployment..."
  echo ""

  log "Secrets created:"
  kubectl get secrets -n "$NAMESPACE" -o wide | grep credentials || \
    warning "No credential secrets found"
  echo ""

  log "Jobs status:"
  kubectl get jobs -n "$NAMESPACE" | grep credential-generator || \
    warning "No credential-generator job found"
  echo ""

  log "Pods status:"
  kubectl get pods -n "$NAMESPACE" -o wide | tail -n +2 | head -20
  echo ""

  success "Deployment complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Wait for pods to be ready: kubectl get pods -n $NAMESPACE -w"
  echo "  2. Check logs: kubectl logs -n $NAMESPACE -l app=postgresql --tail=50"
  echo "  3. List secrets: kubectl get secrets -n $NAMESPACE"
  echo "  4. View a secret: kubectl get secret postgres-credentials -n $NAMESPACE -o yaml"
}

main "$@"
