# Bitbucket Cloud / Server

**Status:** Cloud broken (modules fail to load). Server loads, not exercised.

Catalog + scaffolder modules for Bitbucket. Cloud and Server are four separate packages, and they fail independently. A customer running Bitbucket Server (Data Center) needs only the two Server modules.

**The chart cannot enable Server on its own today.** All four packages hang off the single switch `plugins.bitbucket.enabled` (`charts/developer-hub/templates/configmap-dynamic-plugins.yaml`, the four Bitbucket entries), so turning Bitbucket on also loads the two Cloud modules. They fail at start-up with the error below; the Hub still starts and the Server modules still load. Running Server only needs a separate switch per pair in that template, or the two Cloud entries removed from it.

## Required (when unblocked)

| Layer | What |
|---|---|
| Helm | `plugins.bitbucket.enabled: true` |
| Packages | cloud/server catalog + scaffolder OCI (`bs_1.49.4`). Server only: `backstage-plugin-catalog-backend-module-bitbucket-server`, `backstage-plugin-scaffolder-backend-module-bitbucket-server` |
| Integrations | `integrations.bitbucketCloud` username + app password (and/or Server host+token) |

## Secrets

`BITBUCKET_USERNAME`, `BITBUCKET_APP_PASSWORD`, `BITBUCKET_SERVER_HOST`, `BITBUCKET_SERVER_TOKEN`

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10 | `Cannot find module '@backstage/plugin-bitbucket-cloud-common'` | Overlay is incomplete. Do not rely on Bitbucket scaffolder until a newer overlay includes that package, or vendor a complete export. Golden-path demo publishes to **GitHub** instead. |
| 2026-10-14 | Same error on sandbox3257, RHDH 1.10.5. Fails for `catalog-backend-module-bitbucket-cloud` 0.5.9 and `scaffolder-backend-module-bitbucket-cloud` 0.3.4 only | `catalog-backend-module-bitbucket-server` 0.5.9 and `scaffolder-backend-module-bitbucket-server` 0.2.19 report `loaded dynamic backend plugin`. Untested beyond load: the lab has no Bitbucket Server and the credentials in Vault are stubs. |
| — | `The configuration key 'integrations.bitbucketCloud[0].appPassword' of app is deprecated` | Use `token` in `integrations.bitbucketCloud`. |
