# Microsoft Entra sign-in

**Status:** working

Not a software-catalog tab. Login provider.

## Required

| Layer | What |
|---|---|
| Helm | `auth.microsoft.enabled: true` |
| Azure app | Web redirect `{baseUrl}/api/auth/microsoft/handler/frame` |
| API permissions | `openid`, `profile`, `email`, `User.Read` |
| Resolvers | `emailMatchingUserEntityProfileEmail` then `emailLocalPartMatchingUserEntityName` |
| Values | `domainHint`, `AZURE_*` from Vault |

Guest is **demo-only** (`values-demo.yaml`). Production `signInPage` is `microsoft` only.

## Secrets

`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`

## Known issues

| When | Error | Fix |
|---|---|---|
| earlier | Entra user cannot see templates | LDAP user missing or email mismatch; or session still `user:default/<email>` — sign out and back in |
| — | Rotate leaked client secret | New secret in Azure + Vault `rhdh/azure-client-secret` |
