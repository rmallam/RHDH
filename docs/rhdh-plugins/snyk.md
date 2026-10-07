# Snyk

**Status:** partial (plugin loads; demo is **mocked**)

Vulnerability overview on the Component.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.snyk.enabled: true` |
| Package | self-exported `oci://ghcr.io/rmallam/rhdh-plugin-snyk:bs_1.49.4__2.5.10!backstage-plugin-snyk` |
| Pull secret | `dynamic-plugins-registry-auth` while the GHCR package is private |
| App-config | `snyk.mocked`, `appHost`, `orgSlug` + proxy `/snyk` → `api.snyk.io` |
| Catalog | `snyk.io/org-id`, `snyk.io/org-name`, `snyk.io/project-ids` |

## Secrets

`SNYK_TOKEN`, `SNYK_ORG_SLUG`

Demo sets `plugins.snyk.mocked: true` so the card does not call Snyk SaaS.

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10 | No Red Hat overlay | Export with RHDH CLI 1.10.8 and push GHCR; keep `dynamic-plugins-registry-auth` |
| — | Empty when `mocked: false` | Real org id + project ids + token |
