# ServiceNow

**Status:** partial (SaaS stub)

Change / incident card.

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
| — | Empty card | Real instance URL + an entity id that exists |
