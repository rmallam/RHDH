# Bitbucket Cloud / Server

**Status:** broken (modules fail to load)

Catalog + scaffolder modules for Bitbucket.

## Required (when unblocked)

| Layer | What |
|---|---|
| Helm | `plugins.bitbucket.enabled: true` |
| Packages | cloud/server catalog + scaffolder OCI (`bs_1.49.4`) |
| Integrations | `integrations.bitbucketCloud` username + app password (and/or Server host+token) |

## Secrets

`BITBUCKET_USERNAME`, `BITBUCKET_APP_PASSWORD`, `BITBUCKET_SERVER_HOST`, `BITBUCKET_SERVER_TOKEN`

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10 | `Cannot find module '@backstage/plugin-bitbucket-cloud-common'` | Overlay is incomplete. Do not rely on Bitbucket scaffolder until a newer overlay includes that package, or vendor a complete export. Golden-path demo publishes to **GitHub** instead. |
