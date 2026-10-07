# Jira

**Status:** partial (SaaS stub)

Issue card keyed by project.

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
| — | Empty / stub JSON | Point `baseUrl` at a real Jira and set a project key that exists |
