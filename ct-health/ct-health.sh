#!/bin/bash
# CT Health - A simple health check tool for CallTelemetry Kubernetes deployments

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="ct-dev"
OUTPUT_FORMAT="text"
VERBOSE=false
COMMAND="check-all"

# Function to print colored messages
print_message() {
  echo -e "${2}${1}${NC}"
}

# Function to print usage
print_usage() {
  echo "Usage: ct-health.sh [options] command"
  echo ""
  echo "Commands:"
  echo "  check-all       Run all health checks"
  echo "  check-pods      Check pod health and status"
  echo "  check-services  Check service endpoints and load balancers"
  echo "  check-ingress   Check ingress configurations and routing"
  echo "  check-rbac      Validate RBAC permissions and configurations"
  echo "  check-logs      Analyze logs for errors and warnings"
  echo ""
  echo "Options:"
  echo "  -n, --namespace NAMESPACE  Namespace to check (default: ct-dev)"
  echo "  -o, --output FORMAT        Output format: text, json, yaml (default: text)"
  echo "  -v, --verbose              Enable verbose output"
  echo "  -h, --help                 Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  -n | --namespace)
    NAMESPACE="$2"
    shift
    shift
    ;;
  -o | --output)
    OUTPUT_FORMAT="$2"
    shift
    shift
    ;;
  -v | --verbose)
    VERBOSE=true
    shift
    ;;
  -h | --help)
    print_usage
    exit 0
    ;;
  check-all | check-pods | check-services | check-ingress | check-rbac | check-logs)
    COMMAND="$1"
    shift
    ;;
  *)
    print_message "Unknown option: $1" "$RED"
    print_usage
    exit 1
    ;;
  esac
done

# Check if kubectl is installed
if ! command -v kubectl &>/dev/null; then
  print_message "kubectl not found. Please install kubectl first." "$RED"
  exit 1
fi

# Check if connected to a Kubernetes cluster
if ! kubectl cluster-info &>/dev/null; then
  print_message "Not connected to a Kubernetes cluster. Please configure kubectl." "$RED"
  exit 1
fi

# Function to check pods
check_pods() {
  if $VERBOSE; then
    print_message "Checking pod health in namespace $NAMESPACE..." "$YELLOW"
  fi

  # Get all pods in namespace
  kubectl get pods -n $NAMESPACE

  # Check for pods not in Running or Completed state
  not_running=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running,status.phase!=Completed,status.phase!=Succeeded -o name)
  if [ -n "$not_running" ]; then
    print_message "\nPods not in Running, Completed, or Succeeded state:" "$RED"
    echo "$not_running"
    for pod in $not_running; do
      pod_name=$(echo $pod | cut -d'/' -f2)
      print_message "Suggestion: Check pod logs with kubectl logs -n $NAMESPACE $pod_name" "$YELLOW"
    done
  fi

  # Check for pods with high restart counts
  high_restarts=$(kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$2 > 5 {print $1}')
  if [ -n "$high_restarts" ]; then
    print_message "\nPods with high restart counts:" "$YELLOW"
    echo "$high_restarts"
    for pod in $high_restarts; do
      print_message "Suggestion: Check pod logs with kubectl logs -n $NAMESPACE $pod" "$YELLOW"
    done
  fi
}

# Function to check services
check_services() {
  if $VERBOSE; then
    print_message "Checking services in namespace $NAMESPACE..." "$YELLOW"
  fi

  # Get all services in namespace
  kubectl get services -n $NAMESPACE

  # Check for LoadBalancer services without external IPs
  lb_no_ip=$(kubectl get services -n $NAMESPACE -o jsonpath='{range .items[?(@.spec.type=="LoadBalancer")]}{.metadata.name}{"\t"}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}' | awk '$2 == "" {print $1}')
  if [ -n "$lb_no_ip" ]; then
    print_message "\nLoadBalancer services without external IPs:" "$RED"
    echo "$lb_no_ip"
    print_message "Suggestion: Check MetalLB configuration and status" "$YELLOW"
  fi

  # Check service endpoints
  print_message "\nService Endpoints:" "$YELLOW"
  kubectl get endpoints -n $NAMESPACE
}

# Function to check RBAC
check_rbac() {
  if $VERBOSE; then
    print_message "Checking RBAC configurations for namespace $NAMESPACE..." "$YELLOW"
  fi

  # Check for shared ClusterRole
  if kubectl get clusterrole haproxy-cluster-role-devops &>/dev/null; then
    print_message "ClusterRole 'haproxy-cluster-role-devops' exists" "$GREEN"
  else
    print_message "ClusterRole 'haproxy-cluster-role-devops' does not exist" "$RED"
    print_message "Suggestion: Apply shared RBAC resources: kubectl apply -f examples/haproxy-shared-rbac-narrow.yaml" "$YELLOW"
  fi

  # Check for namespace-specific ClusterRoleBinding
  binding_name="haproxy-ingress-crb-$NAMESPACE"
  if kubectl get clusterrolebinding $binding_name &>/dev/null; then
    print_message "ClusterRoleBinding '$binding_name' exists" "$GREEN"
  else
    print_message "ClusterRoleBinding '$binding_name' does not exist" "$RED"
    print_message "Suggestion: Apply shared RBAC resources: kubectl apply -f examples/haproxy-shared-rbac-narrow.yaml" "$YELLOW"
  fi

  # Check for ServiceAccount
  if kubectl get serviceaccount haproxy-ingress -n $NAMESPACE &>/dev/null; then
    print_message "ServiceAccount 'haproxy-ingress' exists in namespace '$NAMESPACE'" "$GREEN"
  else
    print_message "ServiceAccount 'haproxy-ingress' does not exist in namespace '$NAMESPACE'" "$RED"
    print_message "Suggestion: Apply shared RBAC resources: kubectl apply -f examples/haproxy-shared-rbac-narrow.yaml" "$YELLOW"
  fi
}

# Function to check logs
check_logs() {
  if $VERBOSE; then
    print_message "Analyzing logs for errors in namespace $NAMESPACE..." "$YELLOW"
  fi

  # Get HAProxy pods
  haproxy_pods=$(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress -o name)

  if [ -z "$haproxy_pods" ]; then
    print_message "No HAProxy pods found in namespace $NAMESPACE" "$RED"
    return 1
  fi

  # Check logs for each HAProxy pod
  for pod in $haproxy_pods; do
    pod_name=$(echo $pod | cut -d'/' -f2)
    print_message "Checking logs for $pod_name..." "$YELLOW"

    # Check for RBAC errors
    kubectl logs -n $NAMESPACE $pod_name --tail=100 | grep -i "forbidden" || echo "No RBAC errors found"

    # Check for other errors
    kubectl logs -n $NAMESPACE $pod_name --tail=100 | grep -i "error" || echo "No errors found"
  done
}

# Function to check ingress
check_ingress() {
  if $VERBOSE; then
    print_message "Checking ingress resources in namespace $NAMESPACE..." "$YELLOW"
  fi

  # Get all ingress resources in namespace
  kubectl get ingress -n $NAMESPACE

  # Check HAProxy configuration
  print_message "\nHAProxy ConfigMap:" "$YELLOW"
  kubectl get configmap -n $NAMESPACE -l app.kubernetes.io/name=haproxy-ingress
}

# Run the requested command
case $COMMAND in
check-all)
  print_message "Running all health checks for namespace $NAMESPACE..." "$YELLOW"
  check_pods
  check_services
  check_ingress
  check_rbac
  check_logs
  ;;
check-pods)
  check_pods
  ;;
check-services)
  check_services
  ;;
check-ingress)
  check_ingress
  ;;
check-rbac)
  check_rbac
  ;;
check-logs)
  check_logs
  ;;
*)
  print_message "Unknown command: $COMMAND" "$RED"
  print_usage
  exit 1
  ;;
esac

print_message "\nHealth check completed." "$GREEN"
