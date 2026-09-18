#!/usr/bin/env bash
# ct-compliance-scan.sh — public-repo internal-identifier boundary scanner.
#
# calltelemetry/k8s is the public Kubernetes chart repository (source of
# truth for PRODUCT deployments). Internal tooling identifiers, Linear ticket
# references, ADR citations, DigitalOcean/DOKS cluster identifiers, and
# private (RFC1918) lab/cloud IP addresses do not belong here — see the
# "Customer Data Boundary" and repository-structure source-of-truth rules in
# the owning ai-workspace monorepo. This is a narrower, k8s-repo-scoped
# instance of the same pattern used by the ct-compliance skill's scan.sh in
# ct-meta (denylist + heuristic layers, diff-mode PR gate, allowlist marker).
#
# Layers (always on):
#   1. Team-prefixed ticket IDs   — \b(REL|API|SPA|DOC|UAT|JTA|MED|CTUAT)-[0-9]+
#      (NOT just REL- — a REL-only pattern missed JTA-117 in the past.)
#   2. Internal tokens            — ADR [0-9], ct-meta, DOKS, doks-nyc1,
#                                    cluster-ny1, *.do.calltelemetry.com
#   3. RFC1918 IPv4 addresses     — 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
#
# The IPv4 layer classifies only full dotted-quad candidates
# (`([0-9]{1,3}\.){3}[0-9]{1,3}`), so it does NOT false-positive on chart
# versions (`0.11.13`), image tags (`17-cnpg`), or resource quantities
# (`1000m`) — those never have four dot-separated components. RFC 5737
# documentation addresses (192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24),
# used throughout examples/ and env-*.yaml as placeholders, are NOT RFC1918
# and pass cleanly.
#
# Usage:
#   ct-compliance-scan.sh --diff <base-ref>   scan only what HEAD adds vs <ref>
#                                              (PR gate; ignores legacy debt)
#   ct-compliance-scan.sh [path ...]          scan tracked files (default ".")
#
# Allowlist (narrow, line-scoped — for genuine non-leaks, e.g. this script's
# own doc comments quoting the patterns above): put the literal marker
# `ct-compliance:allow` anywhere on the SAME matched line. A matched line
# carrying the marker counts as allowlisted, not a leak.
#
# Exit: 0 clean | 2 hits found | 1 usage/error.

set -euo pipefail

TICKET_PATTERN='\b(REL|API|SPA|DOC|UAT|JTA|MED|CTUAT)-[0-9]+'
TOKEN_PATTERN='ADR [0-9]|ct-meta|DOKS|doks-nyc1|cluster-ny1|\.do\.calltelemetry\.com'
IPV4_CANDIDATE='([0-9]{1,3}\.){3}[0-9]{1,3}'
RFC1918='^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)'
ALLOW_MARKER='ct-compliance:allow'

err() { printf '%s\n' "$*" >&2; }

diff_ref=""
paths=()
_want_diff=0
for a in "$@"; do
  if [ "$_want_diff" -eq 1 ]; then diff_ref="$a"; _want_diff=0; continue; fi
  case "$a" in
    --diff) _want_diff=1 ;;
    --diff=*) diff_ref="${a#--diff=}" ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) paths+=("$a") ;;
  esac
done
[ "$_want_diff" -eq 1 ] && { err "ct-compliance-scan: --diff needs a <ref> argument"; exit 1; }
[ "${#paths[@]}" -eq 0 ] && paths=(".")

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"
self_path="scripts/ct-compliance-scan.sh"

hits=0
allowed=0
report() { # text
  case "$1" in
    *"$ALLOW_MARKER"*) allowed=$((allowed + 1)); return ;;
  esac
  hits=$((hits + 1))
  printf '  %s\n' "$1"
}

check_ipv4_line() {
  # Flags the line if any dotted-quad candidate on it falls in an RFC1918
  # range. Skips lines carrying the allow marker (handled by report()).
  local line="$1"
  local cand ip
  cand="$(printf '%s' "$line" | grep -oE "$IPV4_CANDIDATE" || true)"
  [ -z "$cand" ] && return
  while IFS= read -r ip; do
    [ -z "$ip" ] && continue
    if printf '%s' "$ip" | grep -qE "$RFC1918"; then
      report "$line"
      return
    fi
  done <<<"$cand"
}

if [ -n "$diff_ref" ]; then
  base="$diff_ref"
  git rev-parse --verify -q "$base" >/dev/null 2>&1 || base="$(git merge-base "$diff_ref" HEAD 2>/dev/null || true)"
  [ -n "$base" ] || { err "ct-compliance-scan: --diff ref '$diff_ref' not resolvable; aborting."; exit 1; }

  _raw="$(git diff "$base"...HEAD -- "${paths[@]}" ':(exclude)'"$self_path" 2>/dev/null)" && _drc=0 || _drc=$?
  [ "${_drc:-0}" -gt 1 ] && { err "ct-compliance-scan: 'git diff $base...HEAD' failed (rc=$_drc); aborting."; exit 1; }
  added="$(printf '%s\n' "$_raw" | grep -E '^\+' | grep -vE '^\+\+\+' || true)"

  added_files="$(git diff --name-only --diff-filter=ACR "$base"...HEAD -- "${paths[@]}" ':(exclude)'"$self_path" 2>/dev/null)" && _frc=0 || _frc=$?
  [ "${_frc:-0}" -gt 1 ] && { err "ct-compliance-scan: 'git diff --name-only $base...HEAD' failed (rc=$_frc); aborting."; exit 1; }

  echo "== team-prefixed ticket IDs (added lines + new paths, vs $base) =="
  while IFS= read -r line; do [ -n "$line" ] && report "$line"; done \
    < <(printf '%s\n' "$added" | grep -EiI -- "$TICKET_PATTERN" || true)
  while IFS= read -r path; do [ -n "$path" ] && report "$path: (ticket ID in new filename)"; done \
    < <(printf '%s\n' "$added_files" | grep -EiI -- "$TICKET_PATTERN" || true)

  echo "== internal tokens (ADR/ct-meta/DOKS/cluster-ny1/*.do.calltelemetry.com) =="
  while IFS= read -r line; do [ -n "$line" ] && report "$line"; done \
    < <(printf '%s\n' "$added" | grep -EiI -- "$TOKEN_PATTERN" || true)

  echo "== RFC1918 IPv4 addresses (added lines) =="
  while IFS= read -r line; do [ -n "$line" ] && check_ipv4_line "$line"; done \
    < <(printf '%s\n' "$added" | grep -EI -- "$IPV4_CANDIDATE" || true)

  echo
  [ "$allowed" -gt 0 ] && echo "ct-compliance-scan: $allowed line(s) allowlisted via '$ALLOW_MARKER' marker."
  if [ "$hits" -gt 0 ]; then
    err "ct-compliance-scan: $hits NEW internal-identifier leak(s) in the diff vs $base."
    err "ct-compliance-scan: this is the public calltelemetry/k8s repo — sanitize before pushing."
    exit 2
  fi
  echo "ct-compliance-scan: clean — no NEW internal identifiers in the diff vs $base."
  exit 0
fi

# ── Full-tree mode (local/manual use; not the PR gate) ──────────────────────
if ! git ls-files --error-unmatch -- "${paths[@]}" >/dev/null 2>&1; then
  err "ct-compliance-scan: invalid or untracked path(s): ${paths[*]}"
  exit 1
fi

echo "== team-prefixed ticket IDs =="
while IFS= read -r line; do [ -n "$line" ] && report "$line"; done \
  < <(git grep -niI -E -- "$TICKET_PATTERN" -- "${paths[@]}" ':(exclude)'"$self_path" 2>/dev/null || true)

echo "== internal tokens =="
while IFS= read -r line; do [ -n "$line" ] && report "$line"; done \
  < <(git grep -niI -E -- "$TOKEN_PATTERN" -- "${paths[@]}" ':(exclude)'"$self_path" 2>/dev/null || true)

echo "== RFC1918 IPv4 addresses =="
while IFS= read -r line; do [ -n "$line" ] && check_ipv4_line "$line"; done \
  < <(git grep -niI -E -- "$IPV4_CANDIDATE" -- "${paths[@]}" ':(exclude)'"$self_path" 2>/dev/null || true)

echo
[ "$allowed" -gt 0 ] && echo "ct-compliance-scan: $allowed line(s) allowlisted via '$ALLOW_MARKER' marker."
if [ "$hits" -gt 0 ]; then
  err "ct-compliance-scan: $hits internal-identifier leak(s) found."
  exit 2
fi
echo "ct-compliance-scan: clean — no internal identifiers detected."
exit 0
