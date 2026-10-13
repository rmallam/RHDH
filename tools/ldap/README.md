# Demo LDAP + Entra (RHDH login and authz)

**Entra** proves identity (OIDC login). **LDAP** is the catalog source for users and groups. RHDH RBAC binds those LDAP groups to roles.

Join key: Entra UPN = LDAP `mail` (`alice@mallamrakeshgmail.onmicrosoft.com`).

## Live wiring on ROSA

Recorded on `rosa-89s85`, which no longer exists. The LDAP side is unchanged on the current cluster; the Hub URL and the redirect URIs are not. Current values: [lab state](../../docs/lab-state/README.md).

| Piece | Where |
|---|---|
| RHDH | https://backstage-developer-hub-rhdh.apps.rosa.rosa-89s85.bhg0.p3.openshiftapps.com |
| Sign-in | `signInPage: microsoft` → Entra tenant `mallamrakeshgmail.onmicrosoft.com` |
| Entra app | existing Graph app `20220108-996c-4f82-96da-1e0df7004afa` (creds in `rhdh` secret `rhdh-secrets`) |
| Redirect URI **you must add** | `https://backstage-developer-hub-rhdh.apps.rosa.rosa-89s85.bhg0.p3.openshiftapps.com/api/auth/microsoft/handler/frame` |
| Redirect already present | `…/api/auth/oidc/handler/frame` |
| LDAP | `ldap://openldap.ldap.svc.cluster.local:389` (`ns ldap`) |
| Catalog | LDAP users `alice` / `bob` / `carol` and groups `developers` / `platform-team` / `app-owners` |
| RBAC | `bob` is admin; `developers` and `app-owners` get the developer role (catalog + scaffolder) |

Guest login was off on `rosa-89s85`. On sandbox3257 it is back: `values-demo.yaml` in `rmallam/rhdh-platform-gitops` lists `guest` on the sign-in page and makes `user:default/guest` an RBAC admin next to `bob`. Take both out before using this lab to demonstrate role separation, or every tester is an administrator.

Open the RHDH URL and use **Sign in** (Microsoft).

### Demo people

| uid | Entra UPN / LDAP mail | Groups | Password | RHDH role |
|---|---|---|---|---|
| `alice` | UPN `alice@…` (Entra **mail** is `mallamrakesh@gmail.com`) | `developers`, `app-owners` | `AliceDev1!` | developer |
| `bob` | `bob@mallamrakeshgmail.onmicrosoft.com` | `platform-team` | `BobPlat1!` | admin |
| `carol` | `carol@mallamrakeshgmail.onmicrosoft.com` | `app-owners` | `CarolApp1!` | developer |

First login as **bob** if you need Administration / RBAC.

### Entra app (reuse, do not create another)

Required on the **same** app you already granted Graph consent to:

- Platform **Web** redirect (required now): `/api/auth/microsoft/handler/frame`.
- Token configuration: optional ID-token claim `email`.
- Delegated Microsoft Graph: `openid`, `profile`, `email`, `User.Read`.

The agent cannot PATCH redirect URIs on this app (Graph `Application.ReadWrite.All` is missing). Add any extra URI in Entra Admin Center → App registrations → the app → Authentication.

---

## LDAP directory

| | Value |
|---|---|
| Namespace | `ldap` |
| Host (in-cluster) | `openldap.ldap.svc.cluster.local` |
| Port | `389` |
| Base DN | `dc=acme,dc=demo` |
| Admin DN | `cn=admin,dc=acme,dc=demo` |
| Admin password | `oc -n ldap get secret openldap-admin -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' \| base64 -d` |

Customer reality: Entra Connect copies on-prem AD/LDAP groups into Entra. This demo keeps the same `cn` / membership on both sides by hand.

---

## Commands

```bash
# Deploy (secret is created if missing)
./tools/ldap/deploy.sh

# System test
./tools/ldap/test-ldap.sh
./tools/ldap/test-ldif.sh

# Manual search
ADMIN=$(oc -n ldap get secret openldap-admin -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d)
oc -n ldap exec deploy/openldap -- ldapsearch -x -LLL -H ldap://127.0.0.1:389 \
  -D cn=admin,dc=acme,dc=demo -w "$ADMIN" -b dc=acme,dc=demo '(objectClass=inetOrgPerson)' uid mail
```

Data is on `emptyDir` — a pod restart reloads the bootstrap LDIF (new empty volume). Anything added by hand with `ldapadd` is lost at that point; put it in `bootstrap.ldif`.

## What this stand-in does not cover

The directory is three `inetOrgPerson` entries and three `groupOfNames`, and the matching Entra users and groups were created by hand. That proves the wiring — Entra signs the user in, LDAP supplies the User and Group entities, RBAC binds the group names. It does not prove any of the following, which are where a real directory differs:

| Not exercised here | Why it matters |
|---|---|
| Active Directory schema | AD users are `objectClass=user` with `sAMAccountName`, `userPrincipalName` and `objectGUID`; groups are `objectClass=group`. The filters and `map:` block in the Hub config are written for `inetOrgPerson` / `groupOfNames` and must be rewritten |
| The join key at scale | Here LDAP `mail` equals the Entra sign-in address because both were typed in. In a synced directory, confirm for the real population that the attribute chosen for `map.email` equals what Entra returns |
| A directory sync | Nothing copies LDAP to Entra. Group membership is kept equal on both sides by hand |
| Paging and size | Three entries. `paged: true` is set but has never returned a second page |
| LDAPS and a private CA | The provider connects on `ldap://…:389` in clear text |
| A read-only bind account | The Hub binds as the directory admin (`cn=admin,dc=acme,dc=demo`) |

Confirm the provider is reading:

```bash
oc -n rhdh logs deploy/backstage-developer-hub -c backstage-backend | grep -E 'Read [0-9]+ LDAP users'
# Read 3 LDAP users and 3 LDAP groups
```
