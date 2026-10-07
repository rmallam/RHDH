# LDAP catalog

**Status:** working

Org catalog (users/groups). Entra authenticates; LDAP is the identity source.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.ldap.enabled: true` and `catalog.ldap.enabled: true` |
| Package | in-tree `catalog-backend-module-ldap` |
| App-config | `catalog.providers.ldapOrg` bind + user/group DNs |
| Join key | LDAP `mail` == Entra profile email (fallback: email local-part == `uid`) |

## Secrets

`LDAP_BIND_PASSWORD`

Demo target: `ldap://openldap.ldap.svc.cluster.local:389`. Users alice / bob / carol.

## Known issues

| When | Error | Fix |
|---|---|---|
| earlier | Microsoft user sees empty catalog | First resolver must not mint `user:default/alice@…`; bind RBAC to `user:default/<uid>` |
