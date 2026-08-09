#!/usr/bin/env bash
set -euo pipefail

chart_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../helm/charts/api" && pwd)"
rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

helm template api "$chart_dir" \
  --namespace ct-dev \
  --set db.useExistingSecret=true \
  --set db.existingSecretName=api-db-secret \
  --set admin.replicas=1 \
  --set api.replicas=0 \
  --set sftp.enabled=false \
  --set logs.enabled=false >"$rendered"

if grep -q '^kind: Secret$' "$rendered"; then
  echo "api chart rendered a database Secret despite db.useExistingSecret=true" >&2
  exit 1
fi

refs="$(grep -c 'name: api-db-secret' "$rendered" || true)"
if [ "$refs" -lt 5 ]; then
  echo "api chart did not reference the configured existing database Secret" >&2
  exit 1
fi

echo "api existing-secret rendering passed (${refs} refs, no generated Secret)"
