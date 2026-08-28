#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

assert_false_defaults() {
  local chart="$1"
  local release="$2"

  helm template "$release" "$chart" --namespace ct-dev >"$rendered"

  for flag in REMOTE_CONTROL_IDENTITY_VERIFICATION_ENABLED REMOTE_CONTROL_SINGLE_NODE_SESSIONS; do
    values="$(awk -v flag="$flag" '
      $0 ~ "name: " flag { found = 1; next }
      found && $1 == "value:" { gsub(/\"/, "", $2); print $2; found = 0 }
    ' "$rendered")"

    if [ "$values" != $'false\nfalse' ]; then
      echo "$chart must render $flag=false in both app deployments; got: ${values:-missing}" >&2
      exit 1
    fi
  done
}

assert_false_defaults "$repo_root/helm/charts/api" api
assert_false_defaults "$repo_root/helm/charts/api-appliance" api-appliance

echo "remote-control identity defaults render false for all Kubernetes app deployments"
