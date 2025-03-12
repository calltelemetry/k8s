#!/bin/bash
# Script to test Helm charts

# Set default values
CHART_DIR="helm/charts"
NAMESPACE="test"
RELEASE_NAME="test-release"
VALUES_FILE=""
SKIP_CRDS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -c|--chart)
      CHART="$2"
      shift
      shift
      ;;
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
    -f|--values)
      VALUES_FILE="$2"
      shift
      shift
      ;;
    --skip-crds)
      SKIP_CRDS=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -c, --chart CHART      Chart to test (default: all charts in $CHART_DIR)"
      echo "  -n, --namespace NS     Namespace to use for testing (default: test)"
      echo "  -r, --release NAME     Release name to use for testing (default: test-release)"
      echo "  -f, --values FILE      Values file to use for testing"
      echo "  --skip-crds            Skip CRD installation (useful for avoiding ownership issues)"
      echo "  -h, --help             Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Function to test a single chart
test_chart() {
  local chart=$1
  local chart_path="$CHART_DIR/$chart"

  echo "=== Testing chart: $chart ==="

  # Check if chart exists
  if [ ! -d "$chart_path" ]; then
    echo "Error: Chart '$chart' not found at $chart_path"
    return 1
  fi

  # Lint the chart
  echo "Linting chart..."
  if ! helm lint "$chart_path" ${VALUES_FILE:+-f "$VALUES_FILE"}; then
    echo "Lint failed for chart: $chart"
    return 1
  fi

  # Render templates
  echo "Rendering templates..."
  if ! helm template "$RELEASE_NAME" "$chart_path" --namespace "$NAMESPACE" ${VALUES_FILE:+-f "$VALUES_FILE"}; then
    echo "Template rendering failed for chart: $chart"
    return 1
  fi

  # Dry run installation
  echo "Performing dry-run installation..."

  # Build the helm install command
  HELM_CMD="helm install \"$RELEASE_NAME\" \"$chart_path\" --namespace \"$NAMESPACE\" ${VALUES_FILE:+-f \"$VALUES_FILE\"} --dry-run"

  # Add --skip-crds flag if specified
  if [ "$SKIP_CRDS" = true ]; then
    HELM_CMD="$HELM_CMD --skip-crds"
    echo "Skipping CRD installation due to potential ownership issues"
  fi

  # Execute the command
  if ! eval $HELM_CMD; then
    echo "Dry-run installation failed for chart: $chart"
    return 1
  fi

  echo "Chart $chart passed all tests!"
  return 0
}

# Main function
main() {
  # If no specific chart is provided, test all charts
  if [ -z "$CHART" ]; then
    echo "Testing all charts in $CHART_DIR..."
    for chart_dir in "$CHART_DIR"/*; do
      if [ -d "$chart_dir" ]; then
        chart=$(basename "$chart_dir")
        test_chart "$chart"
      fi
    done
  else
    # Test the specified chart
    test_chart "$CHART"
  fi
}

# Run the main function
main
