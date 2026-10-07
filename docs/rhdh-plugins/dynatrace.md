# Dynatrace

**Status:** partial (SaaS stub)

Service observability + DQL cards.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.dynatrace.enabled: true` |
| Packages | community dynatrace + DQL frontend/backend OCI |
| pluginConfig | `dynatrace.environments[]` url, tokenUrl, clientId/secret, accountUrn |
| Catalog | `dynatrace.com/dynatrace-entity-id` (e.g. `SERVICE-…`) |

## Secrets

`DYNATRACE_URL`, `DYNATRACE_CLIENT_ID`, `DYNATRACE_CLIENT_SECRET`, `DYNATRACE_ACCOUNT_URN`

Demo: SaaS stub. Kitchen-sink: `SERVICE-DEMO`.

## Known issues

| When | Error | Fix |
|---|---|---|
| — | Empty / OAuth fail | Real environment URL + OAuth client that can read that entity |
