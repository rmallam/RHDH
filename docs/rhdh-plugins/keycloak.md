# Keycloak catalog

**Status:** disabled

Optional Keycloak org provider. This lab uses Entra login + LDAP catalog.

## Required (if enabled)

| Layer | What |
|---|---|
| Helm | `plugins.keycloak.enabled` and `catalog.keycloak.enabled` |
| App-config | `catalog.providers.keycloakOrg` baseUrl, realm, client |

## Secrets

`KEYCLOAK_PLUGIN_CLIENT_ID`, `KEYCLOAK_PLUGIN_CLIENT_SECRET`

## Known issues

None — disabled.
