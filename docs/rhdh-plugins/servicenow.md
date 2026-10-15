# ServiceNow

**Status:** working against a ServiceNow developer instance (since 2026-10-15). The `saas-stubs` path below still works for a cluster without one.

Incident tab keyed by `servicenow.com/entity-id`. In `rhdh-platform-gitops`, `values-demo.yaml` reads the instance URL, user and password from Vault keys `servicenow-base-url`, `servicenow-username` and `servicenow-password`. A reclaimed developer instance gets a new host, so the URL stays out of git; update the Vault key and restart the Hub.

The demo stub returns INC0001001/1002 for `demo` and answers `sys_dictionary` so the plugin schema check passes. `tools/install/wire-rhdh-secrets.py` still writes the stub URL into `SERVICENOW_BASE_URL`, so after a rebuild overwrite the Vault key if you want the developer instance back.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.servicenow.enabled: true` |
| Packages | frontend + backend + scaffolder module OCI |
| pluginConfig | `servicenow.baseUrl` / `instanceUrl` + username/password |
| Catalog | `servicenow.com/entity-id` |

## Secrets

`SERVICENOW_BASE_URL`, `SERVICENOW_USERNAME`, `SERVICENOW_PASSWORD`

Lab (sandbox3257): developer instance, values in Vault. Without one: SaaS stub. Kitchen-sink: `demo`.

Through a corporate proxy, `*.service-now.com` must be on the proxy's allow-list. The lab's Squid (`charts/squid` in `rhdh-platform-gitops`) allows `.service-now.com`.

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10-09 | Empty card on saas-stubs | Stub `/api/now/table/incident` returned `[]` and had no `sys_dictionary` / `u_backstage_entity_id`. Stub now returns two demo incidents and the incident field list. |
| — | Empty against a PDI | Point `SERVICENOW_*` at the PDI and set `u_backstage_entity_id` on the incident |
