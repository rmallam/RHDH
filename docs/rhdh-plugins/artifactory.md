# JFrog Artifactory

**Status:** partial (SaaS stub)

Image / artifact card.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.artifactory.enabled: true` |
| Package | `backstage-community-plugin-jfrog-artifactory` OCI |
| App-config | `artifactory.baseUrl`, `experimentalAnnotations: true` + proxy `/artifactory` |
| Catalog | `jfrog-artifactory/image-name` |

## Secrets

`ARTIFACTORY_BASE_URL`, `ARTIFACTORY_TOKEN`

Demo: SaaS stub. Kitchen-sink image name: `plugin-kitchen-sink`.

## Known issues

| When | Error | Fix |
|---|---|---|
| — | Empty card | Real Artifactory URL + an image that exists |
