# Vault

**Status:** working (lab `-dev` Vault + `pr_1225` overlay)

Secrets-path card for a Component.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.vault.enabled: true` |
| Packages | `backstage-community-plugin-vault` **pr_1225** (no GA `bs_` tag yet) |
| pluginConfig | `vault.baseUrl`, `token`, `secretEngine`, `kvVersion` |
| Catalog | `vault.io/secrets-path: <kv path after mount>` |

## Secrets

`VAULT_ADDR`, `VAULT_TOKEN` (list/read on the engine; lab often uses the dev root)

Demo: `http://vault.vault.svc:8200`, engine `secrets`, KV v2. Kitchen-sink path `rhdh` (same prefix ESO reads).

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10 | No GA `bs_` overlay | Pin `pr_1225__0.19.0` / `pr_1225__0.21.0` in values; swap when Red Hat publishes `bs_` |
| — | Empty list / 403 | Token needs LIST on `secrets/metadata/<path>`; root works on `-dev` |
