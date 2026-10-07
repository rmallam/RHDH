# Demo LDAP + Entra (RHDH login and authz)

**Entra** proves identity (OIDC login). **LDAP** is the catalog source for users and groups. RHDH RBAC binds those LDAP groups to roles.

Join key: Entra UPN = LDAP `mail` (`alice@mallamrakeshgmail.onmicrosoft.com`).

## Live wiring on ROSA

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

Guest login is off. Open the RHDH URL and use **Sign in** (OIDC).

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
./demo/ldap/deploy.sh

# System test
./demo/ldap/test-ldap.sh
./demo/ldap/test-ldif.sh

# Manual search
ADMIN=$(oc -n ldap get secret openldap-admin -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}' | base64 -d)
oc -n ldap exec deploy/openldap -- ldapsearch -x -LLL -H ldap://127.0.0.1:389 \
  -D cn=admin,dc=acme,dc=demo -w "$ADMIN" -b dc=acme,dc=demo '(objectClass=inetOrgPerson)' uid mail
```

Data is on `emptyDir` — a pod restart reloads the bootstrap LDIF (new empty volume).
