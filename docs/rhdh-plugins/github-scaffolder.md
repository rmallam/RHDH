# GitHub scaffolder

**Status:** working

`publish:github` and GitHub catalog locations.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.githubScaffolder.enabled: true` |
| Package | in-tree `scaffolder-backend-module-github` |
| Integrations | `integrations.github.token` |
| Reading allow | `github.com`, `raw.githubusercontent.com`, `api.github.com` |
| RHDH CSV | `scaffolder.template.use`, `scaffolder.task.create/read/cancel` |

## Secrets

`GITHUB_TOKEN` (repo create + contents). Optional `GITHUB_OAUTH_CLIENT_*` only if GitHub login is enabled.

Demo templates publish public repos under `rmallam`. Token lives in Vault → `rhdh-secrets`.

## Known issues

| When | Error | Fix |
|---|---|---|
| earlier | `defaultBranch` rejected | Use `defaultBranch` (this RHDH build accepts it) on `publish:github` |
