# Jira

**Status:** working (demo stub with DEMO tickets)

Issue card keyed by project. The demo stub returns DEMO-1..4 so the kitchen-sink card is not empty. Point `baseUrl` at a Jira Cloud/DC tenant when you have one.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.jira.enabled: true` |
| Package | `roadiehq-backstage-plugin-jira` OCI |
| App-config | `jira.baseUrl`, `token` + proxy `/jira/api` |
| Catalog | `jira/project-key` and optionally `jira/component` |

## Secrets

`JIRA_BASE_URL`, `JIRA_TOKEN`

Demo: `http://saas-stubs.saas-stubs.svc:8080`. Kitchen-sink: `DEMO`.

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10-09 | Empty card on saas-stubs | Stub `/search` returned `issues: []`; Hub proxy only allowed GET while Cloud POSTs `/search/jql`. Stub now returns DEMO tickets; demo Helm sets `jira.product: datacenter` and proxy `allowedMethods: [GET, POST]`. |
| — | Empty against a real Jira | Point `baseUrl` at that tenant and set `jira/project-key` that exists |
