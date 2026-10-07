# IBM API Connect

**Status:** partial (SaaS stub)

APIC catalog sync + proxy.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.apic.enabled: true` |
| Package | `apic-backstage` OCI |
| pluginConfig | `apic[]` name, url, clientId/secret, apiKey + cron `schedule` |
| Proxy | `/apic/api` with `X-IBM-Acme-Id` |

No Component annotation is required for the catalog provider. APIs appear as catalog API entities when sync succeeds.

## Secrets

`APIC_BASE_URL`, `APIC_API_URL`, `APIC_API_KEY`, `APIC_CLIENT_ID`, `APIC_SECRET`

Demo: SaaS stub.

## Known issues

| When | Error | Fix |
|---|---|---|
| — | No API entities | Real APIC manager URL + credentials; stub only answers health |
