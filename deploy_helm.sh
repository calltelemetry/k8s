#!/bin/sh
set -e
rm -rf gs_charts
mkdir -p gs_charts

gsutil -m rsync gs://ct_charts gs_charts/

find charts -maxdepth 1 -mindepth 1 -type d | while read -r CHART; do
	helm dep update "${CHART}"
	helm package "${CHART}" --destination gs_charts
done

helm repo index gs_charts/ --url "https://storage.googleapis.com/ct_charts"

gsutil -m -h "Cache-Control:private, max-age=0, no-transform" rsync gs_charts gs://ct_charts 
