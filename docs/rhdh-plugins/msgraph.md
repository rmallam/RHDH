# Microsoft Graph catalog

**Status:** disabled

Optional Entra user/group sync. This lab uses **LDAP** as the org source.

## Required (if enabled)

| Layer | What |
|---|---|
| Helm | `plugins.msgraph.enabled` and `catalog.msgraph.enabled` |
| Azure | Application permission `User.Read.All` (admin consent) |
| App-config | `catalog.providers.microsoftGraphOrg` |

Leave off unless the bank wants Entra groups in the catalog. Enabling Graph does not replace Entra **login**.

## Known issues

None — disabled.
