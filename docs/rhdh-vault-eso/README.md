# RHDH secrets from the customer’s HashiCorp Vault

Two different Vault uses. Do not mix them.

| Use | Who authenticates | Permission | What it is for |
|---|---|---|---|
| **A. Deploy RHDH** | External Secrets Operator (or Vault Secrets Operator) | **read** on `kv/…/secrets/rhdh/*` | Fill the Kubernetes Secret `rhdh-secrets` that the Backstage CR mounts as env |
| **B. Vault plugin in the portal** | RHDH app (`VAULT_TOKEN`) | **LIST only** on app K/V v2 paths | Show secret *names* on a catalog entity. Never put payload values in RHDH |

This folder is **A**. The LIST-only plugin is **B** (`docs/rhdh-disconnected-plugins`).

This GitOps repo already does A: `ExternalSecret/rhdh-secrets` → ClusterSecretStore `vault-secret-store` → Kubernetes Secret `rhdh-secrets` → `spec.application.extraEnvs.secrets`.

```
docs/rhdh-vault-eso/
  README.md                 ← this file
  manifests/
    cluster-secret-store.yaml
    externalsecret-rhdh.yaml
    vault-policy-rhdh-read.hcl
```

---

## 1. What the customer must already have

- HashiCorp Vault (their instance), KV **v2** engine
- A way for the OpenShift cluster to reach Vault (network + TLS CA)
- Either:
  - **External Secrets Operator** (what this repo assumes), or
  - **Vault Secrets Operator** (HashiCorp) if that is the bank standard

Do **not** put RHDH client secrets in Git. Do **not** use Vault Agent Injector as the primary path for the RHDH operator: the Backstage CR expects a normal Secret named `rhdh-secrets`.

---

## 2. Vault side (once per cluster)

### Engine and paths

KV v2 mount `kv` (adjust if theirs is `secret`). Paths:

```text
kv/data/secrets/rhdh/<name>     # property: value
```

Seed (example):

```bash
export VAULT_ADDR=https://vault.customer.example.com
vault kv put kv/secrets/rhdh/backend-secret value="$(openssl rand -hex 32)"
vault kv put kv/secrets/rhdh/azure-tenant-id value="..."
vault kv put kv/secrets/rhdh/azure-acme-id value="..."
vault kv put kv/secrets/rhdh/azure-acme-secret value="..."
vault kv put kv/secrets/rhdh/ldap-bind-password value="..."
# …every key in manifests/externalsecret-rhdh.yaml
```

### Policy (ESO read)

Apply `manifests/vault-policy-rhdh-read.hcl`:

```bash
vault policy write rhdh-read manifests/vault-policy-rhdh-read.hcl
```

### Kubernetes auth

Vault must trust this cluster’s SA tokens (their IAM/Vault team usually already did this for other apps).

```bash
vault write auth/kubernetes/role/rhdh-role \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=rhdh-read \
  ttl=1h
```

If ESO runs in another namespace or SA name, change the bind. The **ClusterSecretStore** `serviceAccountRef` must match this role.

A separate **LIST-only** policy + token is used for the Vault *plugin* (`secrets/rhdh/vault-list-token`). That token is stored *in* Vault as a secret that ESO copies into `rhdh-secrets` as `VAULT_TOKEN`. It must not be allowed to `read` secret payloads.

---

## 3. Cluster: SecretStore + ExternalSecret

1. Confirm ESO is installed (`oc get crd clustersecretstores.external-secrets.io`).
2. Edit `manifests/cluster-secret-store.yaml` (`server`, CA, SA, KV path).
3. Apply store **once** (cluster-scoped; often owned by the platform team, not the RHDH app of apps):

```bash
oc apply -f docs/rhdh-vault-eso/manifests/cluster-secret-store.yaml
```

4. Apply the ExternalSecret in `rhdh` (already in GitOps as `components/developer-hub/base/instance/secret-env.yaml`):

```bash
oc apply -f docs/rhdh-vault-eso/manifests/externalsecret-rhdh.yaml
# or via Argo: kustomization already includes instance/secret-env.yaml
```

5. Wait until the Kubernetes Secret exists:

```bash
oc -n rhdh get externalsecret rhdh-secrets
oc -n rhdh get secret rhdh-secrets
# SecretSynced / SecretSyncedError
```

6. The Backstage CR must list that Secret (already set):

```yaml
spec:
  application:
    extraEnvs:
      secrets:
        - name: rhdh-secrets
```

`${AZURE_CLIENT_SECRET}`, `${LDAP_BIND_PASSWORD}`, `${SERVICENOW_PASSWORD}`, … in app-config then resolve from the pod environment. No values in Git.

`refreshInterval: 5m` — rotate in Vault; ESO rewrites the Secret; restart RHDH if a key was added (env is fixed at pod start).

---

## 4. If they standardised on Vault Secrets Operator instead of ESO

Same Kubernetes Secret name and keys. Replace `ExternalSecret` with a `VaultStaticSecret` (or equivalent) whose `destination.name` is `rhdh-secrets`. The Backstage CR does not change.

---

## 5. Prove it

```bash
oc -n rhdh get externalsecret rhdh-secrets -o yaml | grep -A5 status
oc -n rhdh exec deploy/backstage-developer-hub -c backstage-backend -- \
  /bin/sh -c 'test -n "$AZURE_CLIENT_ID" && echo AZURE_CLIENT_ID=set'
```

Do not `echo` secret values. Logs must not contain Vault tokens. App-config must keep `${…}` placeholders.

---

## 6. What you do *not* store in Vault for RHDH

- Plugin OCI images (those go to the internal **container** registry)
- GitOps YAML
- The ESO Kubernetes auth itself (that is Vault kubernetes auth + SA)

TLS CA for Vault: mount into the ESO controller (and `install-dynamic-plugins` only if a plugin talks to Vault at install time — it does not).
