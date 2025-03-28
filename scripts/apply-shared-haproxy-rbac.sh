#!/bin/bash
# Script to apply shared RBAC resources for HAProxy ingress controllers
# and update HAProxy installations in multiple namespaces

set -e

echo "Ensuring namespaces exist..."
kubectl create namespace ct-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace ct-prod --dry-run=client -o yaml | kubectl apply -f -

echo "Applying shared RBAC resources..."
kubectl apply -f ./examples/haproxy-shared-rbac-narrow.yaml

echo "Verifying RBAC resources..."
kubectl get clusterrole haproxy-cluster-role-devops
kubectl get clusterrolebinding haproxy-ingress-crb-ct-dev haproxy-ingress-crb-ct-prod

echo "Uninstalling existing HAProxy ingress controllers (if any)..."
helm uninstall haproxy-ingress -n ct-dev || true
helm uninstall haproxy-ingress -n ct-prod || true

echo "Installing HAProxy ingress controller in ct-dev namespace..."
# Use --skip-crds to avoid creating CRDs that might conflict
helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-dev -f haproxy-ct-dev-values.yaml --skip-crds

echo "Installing HAProxy ingress controller in ct-prod namespace..."
# Use --skip-crds to avoid creating CRDs that might conflict
helm install haproxy-ingress haproxy-ingress/haproxy-ingress -n ct-prod -f haproxy-ct-prod-values.yaml --skip-crds

echo "Verifying installations..."
kubectl get pods -n ct-dev -l app.kubernetes.io/name=haproxy-ingress
kubectl get pods -n ct-prod -l app.kubernetes.io/name=haproxy-ingress

echo "Updating ingress-haproxy chart in ct-dev namespace..."
helm upgrade ingress-haproxy ./helm/charts/ingress -n ct-dev -f ingress-ct-dev-values.yaml

echo "Checking for any RBAC-related errors in the logs..."
kubectl logs -n ct-dev -l app.kubernetes.io/name=haproxy-ingress | grep -i "forbidden" || echo "No RBAC errors found in ct-dev"
kubectl logs -n ct-prod -l app.kubernetes.io/name=haproxy-ingress | grep -i "forbidden" || echo "No RBAC errors found in ct-prod"

echo "Done! HAProxy ingress controllers are now installed in multiple namespaces with shared RBAC resources."
