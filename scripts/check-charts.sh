#!/bin/bash
# Script to check if the required charts exist in the repositories
# This script will check if the charts referenced in the helmfile exist

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

# Update helm repositories
print_message "Updating helm repositories..." "$YELLOW"
helm repo update

# Check if charts exist
print_message "\nChecking if required charts exist..." "$YELLOW"

# List of charts to check
charts=(
  "haproxy-ingress/haproxy-ingress"
  "metallb/metallb"
  "nats/nats"
  "calltelemetry/ingress"
  "calltelemetry/api"
  "calltelemetry/vue-web"
  "calltelemetry/traceroute"
  "calltelemetry/echo"
)

# Check each chart
for chart in "${charts[@]}"; do
  print_message "Checking chart: $chart" "$YELLOW"
  if helm search repo "$chart" --output yaml | grep -q "version:"; then
    print_message "✅ Chart $chart exists" "$GREEN"
    helm search repo "$chart" --output yaml | grep -E "name:|version:|appVersion:"
    echo ""
  else
    print_message "❌ Chart $chart does not exist" "$RED"
  fi
done

# Check if local charts exist as an alternative
print_message "\nChecking if local charts exist as an alternative..." "$YELLOW"

local_charts=(
  "helm/charts/ingress"
  "helm/charts/api"
  "helm/charts/vue-web"
  "helm/charts/traceroute"
  "helm/charts/echo"
)

for chart in "${local_charts[@]}"; do
  if [ -d "$chart" ] && [ -f "$chart/Chart.yaml" ]; then
    print_message "✅ Local chart $chart exists" "$GREEN"
    cat "$chart/Chart.yaml" | grep -E "name:|version:|appVersion:"
    echo ""
  else
    print_message "❌ Local chart $chart does not exist or is not a valid chart" "$RED"
  fi
done

print_message "\nChart check completed." "$GREEN"
print_message "If any charts are missing, you may need to add the repository or use local charts." "$YELLOW"
print_message "To use local charts, update the helmfile.yaml to use paths like './helm/charts/ingress' instead of 'calltelemetry/ingress'." "$YELLOW"
