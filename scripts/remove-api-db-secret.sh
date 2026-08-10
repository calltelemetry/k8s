#!/usr/bin/env bash
# The published API chart 0.11.12 always renders api-db-secret even when the
# deployments are configured to use an existing secret. Remove only that
# rendered object so the protected, bootstrap-managed secret cannot be
# overwritten by Helm. The same post-renderer pins the application images by
# digest because these chart versions accept tags but do not expose digest
# values.
set -euo pipefail

remove_api_db_secret=false
strip_cert_manager=false
case "${1:-}" in
  --remove-api-db-secret) remove_api_db_secret=true ;;
  --strip-cert-manager) strip_cert_manager=true ;;
  "") ;;
  *) echo "unknown post-renderer option: $1" >&2; exit 2 ;;
esac

web_repository="${CT_WEB_IMAGE_REPOSITORY:-}"
web_tag="${CT_WEB_IMAGE_TAG:-}"
web_digest="${CT_WEB_IMAGE_DIGEST:?CT_WEB_IMAGE_DIGEST must be set}"
vue_repository="${CT_VUE_IMAGE_REPOSITORY:-}"
vue_tag="${CT_VUE_IMAGE_TAG:-}"
vue_digest="${CT_VUE_IMAGE_DIGEST:?CT_VUE_IMAGE_DIGEST must be set}"

[[ "$web_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "invalid CT_WEB_IMAGE_DIGEST" >&2; exit 2; }
[[ "$vue_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || { echo "invalid CT_VUE_IMAGE_DIGEST" >&2; exit 2; }

if ! awk -v remove_api_db_secret="$remove_api_db_secret" -v strip_cert_manager="$strip_cert_manager" \
  -v web_repository="$web_repository" -v web_tag="$web_tag" -v web_digest="$web_digest" \
  -v vue_repository="$vue_repository" -v vue_tag="$vue_tag" -v vue_digest="$vue_digest" '
  function flush() {
    if (remove_api_db_secret != "true" || doc !~ /kind:[[:space:]]*Secret/ || doc !~ /name:[[:space:]]*api-db-secret/) {
      printf "%s", doc
    }
    doc = ""
  }
  /^---[[:space:]]*$/ { flush(); doc = $0 "\n"; next }
  {
    line = $0
    if (strip_cert_manager == "true" && index(line, "cert-manager.io/cluster-issuer:") > 0) {
      next
    }
    if (web_digest != "" && index(line, "image: " web_repository ":" web_tag) > 0) {
      sub(web_repository ":" web_tag, web_repository "@" web_digest, line)
      web_replaced = 1
    } else if (web_digest != "" && index(line, "image: \"" web_repository ":" web_tag "\"") > 0) {
      sub("\"" web_repository ":" web_tag "\"", "\"" web_repository "@" web_digest "\"", line)
      web_replaced = 1
    }
    if (vue_digest != "" && index(line, "image: " vue_repository ":" vue_tag) > 0) {
      sub(vue_repository ":" vue_tag, vue_repository "@" vue_digest, line)
      vue_replaced = 1
    } else if (vue_digest != "" && index(line, "image: \"" vue_repository ":" vue_tag "\"") > 0) {
      sub("\"" vue_repository ":" vue_tag "\"", "\"" vue_repository "@" vue_digest "\"", line)
      vue_replaced = 1
    }
    doc = doc line "\n"
  }
  END {
    flush()
    if (remove_api_db_secret == "true" && web_replaced != 1) exit 10
    if (strip_cert_manager == "true" && vue_replaced != 1) exit 11
  }
'; then
  echo "post-renderer did not find every required immutable application image" >&2
  exit 1
fi
