---
session_id: 2026-06-01_19-33
date: 2026-06-01
repo: k8s
branch: main
related_repos: [ai-workspace, ct-meta]
---

# Chart fix: umbrella caddy default tag

## Context
During a DOKS `0.8.6-stable` preview deploy, the gateway failed to pull. Part of
the cause was a chart default pointing at a caddy tag that doesn't exist.

## Change
- `helm/charts/calltelemetry/values.yaml`: `caddy.image.tag` `2.11.3` → **`7a7c1b3`**.
  Docker Hub `calltelemetry/caddy` has no bare `2.11.3` tag (only `v2.11.x`, `v2.10.x`,
  and short-SHA tags). `7a7c1b3` is verified-published (HTTP 200) and matches the
  `caddy-builder` gitlink — the security-hardened Caddy rebuild.

## Key decisions
- Pinned to the short-SHA hardened build (matches caddy-builder gitlink, verified pullable) rather than a floating `v2.11`/`latest`.

## Confidence
90/100 — tag pull verified HTTP 200; not re-rendered through a full prod helmfile pass.

## Cross-references
- [ai-workspace recap](../../../docs/sessions/2026-06-01_19-33_doks-stable-preview-deploy-hardening.md)
