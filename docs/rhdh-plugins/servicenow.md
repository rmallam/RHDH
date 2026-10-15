# ServiceNow

**Status:** working against a ServiceNow developer instance (since 2026-10-15), with ServiceNow calls going through the lab's authenticated Squid proxy. The `saas-stubs` path below still works for a cluster without one.

Incident tab keyed by `servicenow.com/entity-id`. In `rhdh-platform-gitops`, `values-demo.yaml` reads the instance URL, user and password from Vault keys `servicenow-base-url`, `servicenow-username` and `servicenow-password`. A reclaimed developer instance gets a new host, so the URL stays out of git; update the Vault key and restart the Hub.

The demo stub returns INC0001001/1002 for `demo` and answers `sys_dictionary` so the plugin schema check passes.

**After a rebuild.** `tools/install/wire-rhdh-secrets.py` writes the stub URL and stub credentials into `SERVICENOW_BASE_URL`, `SERVICENOW_USERNAME` and `SERVICENOW_PASSWORD`, and `scripts/seed-vault.py` copies all three into Vault. To get the developer instance back, overwrite all three keys under `secrets/rhdh/` (`servicenow-base-url`, `servicenow-username`, `servicenow-password`) after seeding, wait for External Secrets to refresh `rhdh-secrets` (`refreshInterval: 5m`), then restart the Hub. Restoring only the URL leaves authentication on the stub credentials.

## Through a proxy

Since 2026-10-15 `values-deploy.yaml` in `rhdh-platform-gitops` sets `httpProxy.enabled: true`. The plugin has no proxy setting of its own: the Hub process uses `HTTP_PROXY`, `HTTPS_PROXY` and `NO_PROXY` from Vault keys `rhdh/http-proxy`, `rhdh/https-proxy` and `rhdh/no-proxy`. `NO_PROXY` lists every other host the Hub dials, so in the lab only ServiceNow is proxied. The proxy log shows `TCP_TUNNEL/200` for the ServiceNow host. The plugin-install init container stays off the proxy (`initContainer: ""`), because registry pulls redirect to CDNs the allow-list refuses.

Proxy authentication is Basic only, and the ServiceNow credential travels inside the tunnel, separate from the proxy credential. What to ask a customer about their proxy is in `charts/developer-hub/PROXY-AUTH.md` in `rhdh-platform-gitops`.

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
