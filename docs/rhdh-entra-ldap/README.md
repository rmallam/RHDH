# RHDH + Entra login + LDAP authorization

Customer playbook. Entra proves **who the user is**. LDAP is the **users/groups catalog**. RHDH RBAC binds **LDAP group names** to roles.

This is what worked on the ROSA demo. Copy this folder; replace the placeholders in `manifests/`. Do **not** reuse a privileged Graph admin app in production — register a dedicated `rhdh-login` app.

```
docs/rhdh-entra-ldap/
  README.md                 ← this file
  manifests/
    kustomization.yaml      ← oc apply -k
    app-config.yaml
    dynamic-plugins.yaml
    rbac-policies.csv
    backstage-cr.yaml
    rhdh-secrets.example.yaml
```

---

## 1. Get these values from the customer (before you touch RHDH)

- RHDH public URL (the Route), e.g. `https://backstage.apps.<cluster>/`
- Entra **Tenant ID**
- Entra **primary domain** (for `domainHint`), e.g. `westpac.co.nz`
- LDAP host, port, TLS (ldaps vs ldap), **bind DN**, bind password, **user base DN**, **group base DN**, user/group filters
- Which LDAP attribute is the **login email** (`mail` in the demo)
- Which LDAP attribute is the **user id** (`uid` here → catalog name `user:default/<uid>`)
- Group object class (`groupOfNames` here) and **member** attribute
- Exact **group CNs** that should map to RHDH roles (demo: `developers`, `app-owners`, `platform-team`)
- Who should be RHDH admin (`user:default/<uid>`)

---

## 2. Register a dedicated Entra app (AuthN only)

In **Entra admin center → App registrations → New registration**:

1. Name it `rhdh-login` (not the Graph provisioning / user-admin app).
2. Supported account types: **this tenant only**.
3. Platform **Web** redirect URI (this is what unblocked login):

   `https://<rhdh-host>/api/auth/microsoft/handler/frame`

4. **Certificates & secrets** → create a client secret. Store Tenant ID, Application (client) ID, and secret in Vault / `rhdh-secrets`. Never commit them.
5. **API permissions** — **Delegated**, then **Grant admin consent**:
   - `openid`
   - `profile`
   - `email`
   - `User.Read`
   - `offline_access`
6. Optional but useful: **Token configuration** → ID token optional claim **`email`**.

Do **not** use generic OIDC (`signInPage: oidc`) against Entra. That path only sees the ID token; many workforce users have **no `email` claim**. The **Microsoft** provider calls Graph and uses `mail`, then UPN. That is what made the demo work.

---

## 3. Align the join key (this is the usual production break)

RHDH matches the Entra profile to an LDAP **User** entity, in this order (see `manifests/app-config.yaml`):

1. `emailMatchingUserEntityProfileEmail` — Entra `mail` (or UPN if `mail` is empty) **must equal** LDAP `mail`
2. Fallback: `emailLocalPartMatchingUserEntityName` — local-part of that email **must equal** LDAP `uid`

Customer checks:

- Every user who will log in exists in LDAP with `mail` set.
- That `mail` matches what Graph returns (`mail` if present, otherwise UPN).
- If HR mail ≠ UPN, LDAP `mail` must be the **Graph `mail`**, not the UPN. The demo hit this: Alice’s Entra mail was a personal Gmail, not her UPN.

For a bank, turn **off** `dangerouslyAllowSignInWithoutUserInCatalog` once LDAP is complete. Leave it on only while proving login.

---

## 4. Point RHDH at **their** LDAP (AuthZ / catalog)

Keep the LDAP catalog plugin enabled (`backstage-plugin-catalog-backend-module-ldap-dynamic` in `manifests/dynamic-plugins.yaml`).

Change only customer-specific bits in `manifests/app-config.yaml`:

| Placeholder | Replace with |
|---|---|
| `https://backstage.apps.CLUSTER_DOMAIN` | customer RHDH Route |
| `customer.example.com` (`domainHint`) | Entra primary domain |
| `ldaps://ldap.customer.example.com:636` | their LDAP/LDAPS URL |
| `cn=svc-rhdh,ou=service-accounts,dc=customer,dc=example` | their bind DN |
| `ou=people,...` / `ou=groups,...` | their people / groups OUs |
| `(objectClass=inetOrgPerson)` | their user filter |
| `(objectClass=groupOfNames)` | their group filter (`group` if AD) |
| `map.name: uid` / `map.email: mail` | their id + email attributes |
| `map.members: member` | `member` vs `uniqueMember` vs `memberUid` |
| `user:default/REPLACE_ADMIN_UID` | LDAP uid of the platform admin |

If they use **LDAPS**, trust their CA (often a ConfigMap mounted into the RHDH pod).

Do **not** install the demo OpenLDAP at the customer. That directory is a stand-in for their corporate LDAP/AD.

---

## 5. Put secrets in `rhdh-secrets` (same keys, their values)

Copy `manifests/rhdh-secrets.example.yaml` and fill it (or use Vault / ExternalSecret). Keys:

| Key | Meaning |
|---|---|
| `BACKEND_SECRET` | RHDH session secret |
| `AZURE_TENANT_ID` | customer tenant |
| `AZURE_CLIENT_ID` | `rhdh-login` app id |
| `AZURE_CLIENT_SECRET` | `rhdh-login` secret |
| `LDAP_BIND_PASSWORD` | LDAP bind password |
| `GITHUB_TOKEN` | optional; only if you keep GitHub scaffolder |

Wire that secret on the Backstage CR (`extraEnvs.secrets`). Mount the RBAC CSV via `extraFiles` (`rbac-policies` ConfigMap → `/opt/app-root/src/rbac-policies.csv`). Both are already in `manifests/backstage-cr.yaml`.

---

## 6. Map **their** LDAP groups in the RBAC CSV

`manifests/rbac-policies.csv` today:

- role `developer` → catalog + scaffolder
- `group:default/developers` and `group:default/app-owners` get that role

At the customer:

1. Keep LDAP **group `cn`** as the RHDH group name (`group:default/<cn>`).
2. Replace `developers` / `app-owners` with **their** CNs (or add rows).
3. Do **not** assign `role:default/rbac_admin` from the CSV — that role is owned by `permission.rbac.admin` in app-config.
4. Platform admins go in app-config; everyone else goes through LDAP groups → CSV.

---

## 7. Apply

```bash
# 1. Edit placeholders in manifests/app-config.yaml, rbac-policies.csv, backstage-cr.yaml
# 2. Create the secret (do not commit the filled file)
oc -n rhdh apply -f manifests/rhdh-secrets.example.yaml   # after renaming and filling

# 3. ConfigMaps + Backstage CR
oc apply -k docs/rhdh-entra-ldap/manifests

# 4. If the CR already exists, apply ConfigMaps then restart
oc -n rhdh rollout restart deploy/backstage-developer-hub
oc -n rhdh rollout status deploy/backstage-developer-hub
```

If the live CR name is not `developer-hub`, change `metadata.name` in `backstage-cr.yaml` (or patch the existing CR with the `extraEnvs` / `extraFiles` / `appConfig` / `dynamicPluginsConfigMapName` fields only).

---

## 8. Prove it

Logs must show:

- `Configuring auth provider: microsoft`
- `Read N LDAP users and M LDAP groups`

Then:

1. Catalog → Users/Groups: LDAP people and groups present, `spec.profile.email` correct.
2. Sign in with a real Entra user who exists in LDAP.
3. Confirm identity is `user:default/<uid>` (not a Gmail local-part, not a raw UPN).
4. Confirm group membership and scaffolder/RBAC match the CSV.

---

## What you copy vs what you replace

**Copy as-is:** Microsoft provider (not OIDC), LDAP catalog plugin, RBAC CSV pattern, secret keys, extraFiles mount, redirect path `/api/auth/microsoft/handler/frame`.

**Replace:** tenant, client id/secret, domainHint, RHDH URL, LDAP URL/DNs/filters/attributes, group CNs, admin user, LDAP `mail` so it matches Graph `mail`.

**Leave behind:** the demo OpenLDAP, alice/bob/carol, the Graph admin app, and `dangerouslyAllowSignInWithoutUserInCatalog` once catalog coverage is complete.
