# Red Hat Developer Hub (lab)

Helm chart, Argo CD Applications, and **separate** tool-install manifests for the ROSA demo.

The RHDH Helm chart does **not** install Jenkins, SonarQube, Vault, or SaaS stubs. Those live under `tools/` and have their own Argo apps.

## Layout

| Path | What it is |
|---|---|
| `charts/developer-hub` | RHDH 1.10 Backstage CR, plugins, app-config, ExternalSecret |
| `argocd/apps` | Argo Applications (Hub + tools + ESO store) |
| `tools/{jenkins,sonarqube,vault,saas-stubs,ldap}` | Test-only installs (not part of the Helm chart) |
| `tools/eso` | ClusterSecretStore → Vault |
| `tools/install` | `deploy.sh` + secret wiring for a fresh cluster |
| `scripts/seed-vault.py` | Copy `rhdh-secrets` → Vault KV `secrets/rhdh/*` |
| `docs/` | Entra/LDAP, disconnected plugins, Vault/ESO notes |

Workshop / HLD documents are **not** in this repo.

## Recreate the cluster

1. OpenShift GitOps must already be installed (creates `openshift-gitops`).
2. Apply the Applications (after this repo is pushed):

```bash
oc apply -f argocd/apps
```

3. First-time Vault + ESO (tokens are not in git):

```bash
# Vault root token + Jenkins/Sonar API tokens
./tools/install/deploy.sh
# Copy live rhdh-secrets into Vault and create external-secrets/vault-eso-token
python3 scripts/seed-vault.py
oc apply -f tools/eso/cluster-secret-store.yaml
```

4. Hub reads secrets from Vault via ExternalSecret `rhdh-secrets` (`secrets.mode: eso`).

## What to change for another cluster

Edit `charts/developer-hub/values-demo.yaml`:

- `app.baseUrl` and `app.clusterBaseDomain`
- `auth.microsoft.domainHint`
- tool URLs if they are not the in-cluster defaults
- catalog `locations`

Seed Entra / GitHub / LDAP values in Vault (`secrets/rhdh/<key>` property `value`), then let ESO refresh. Do not commit secret values.

## Plugin notes

- **Vault plugin** uses the `pr_1225` overlay (no GA `bs_` tag yet).
- **Bitbucket** plugins are on; demo credentials are stubs in Vault until you add a real workspace.
- **Snyk** stays `mocked: true` in the demo overlay.
- SaaS plugins (Jira, ServiceNow, Dynatrace, APIC, Artifactory) point at `saas-stubs`.
