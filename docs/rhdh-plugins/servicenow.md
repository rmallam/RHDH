# ServiceNow

**Status:** working (demo stub with INC tickets)

Incident tab keyed by `servicenow.com/entity-id`. The demo stub returns INC0001001/1002 for `demo` and answers `sys_dictionary` so the plugin schema check passes. Swap `SERVICENOW_*` to a PDI when you have one.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.servicenow.enabled: true` |
| Packages | frontend + backend + scaffolder module OCI |
| pluginConfig | `servicenow.baseUrl` / `instanceUrl` + username/password |
| Catalog | `servicenow.com/entity-id` |

## Secrets

`SERVICENOW_BASE_URL`, `SERVICENOW_USERNAME`, `SERVICENOW_PASSWORD`

Demo: SaaS stub. Kitchen-sink: `demo`.

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10-09 | Empty card on saas-stubs | Stub `/api/now/table/incident` returned `[]` and had no `sys_dictionary` / `u_backstage_entity_id`. Stub now returns two demo incidents and the incident field list. |
| — | Empty against a PDI | Point `SERVICENOW_*` at the PDI and set `u_backstage_entity_id` on the incident |
