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
| RHDH CSV | `scaffolder.template.use`, `scaffolder.template.parameter.read`, `scaffolder.template.step.read`, `scaffolder.action.execute`, `scaffolder.task.create/read/cancel`, `catalog.location.create` |

## Secrets

`GITHUB_TOKEN` (repo create + contents). Optional `GITHUB_OAUTH_CLIENT_*` only if GitHub login is enabled.

Demo templates publish public repos under `rmallam`. Token lives in Vault → `rhdh-secrets`.

After you push `golden-path/demo/template-*.yaml`, Hub does not pick it up until the catalog Location is refreshed. There is no Refresh on the Create wizard — see [Force a Hub catalog refresh](../rhdh-catalog-refresh/README.md).

## Known issues

| When | Error | Fix |
|---|---|---|
| earlier | `defaultBranch` rejected | Use `defaultBranch` (this RHDH build accepts it) on `publish:github` |
| 2026-10-08 | No Refresh on Create after a template Git push | `POST /api/catalog/refresh` on the Location + Template ([runbook](../rhdh-catalog-refresh/README.md)) |
| 2026-10-08 | Output links `https://github.com///blob/main/Jenkinsfile` | This Hub does not interpolate `parameters.*` in `output.links`. Use `steps['publish'].output.remoteUrl`. |
| 2026-10-08 | Create form has no app/repo name; task finishes in ms with 0 steps; Dev Spaces `url=` empty | `pluginsWithPermission` includes `scaffolder` but CSV lacked `scaffolder.template.parameter.read`, `scaffolder.template.step.read`, and `scaffolder.action.execute`. Without those, Hub hides every template field and runs no steps. |
