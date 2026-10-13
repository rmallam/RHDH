# Runbooks

One folder per topic. Each has a `README.md`, and most have `tests/test-docs.sh`, which fails if a pin or a required section is deleted.

Start with **lab-state**. It says which cluster is current and what is deployed; every other page says how one piece is built.

| Runbook | Covers | Last proven on |
|---|---|---|
| [lab-state](lab-state/README.md) | Current cluster, installed versions, Argo apps, what is in git but not deployed, lab-only settings, rebuild order | sandbox3257, 2026-10-14 |
| [service-mesh-ambient](service-mesh-ambient/README.md) | Service Mesh 3 in ambient mode: what the chart installs, enrolment labels, what is not proven yet | sandbox3257, 2026-10-14 (control plane only) |
| [devspaces](devspaces/README.md) | Dev Spaces `CheCluster` settings, the dedicated ingress shard, storage caveats | sandbox3257, 2026-10-14 |
| [rhdh-plugins](rhdh-plugins/README.md) | One page per Hub plugin, status table, installed versions | Status table: rosa-89s85. Installed versions: sandbox3257 |
| [rhdh-disconnected-plugins](rhdh-disconnected-plugins/README.md) | Mirroring OCI plugins, `registries.conf` for the init container, the pin list | rosa-89s85 |
| [rhdh-entra-ldap](rhdh-entra-ldap/README.md) | Entra sign-in with LDAP as the user and group source | rosa-89s85 |
| [rhdh-cnpg](rhdh-cnpg/README.md) | CloudNativePG as the Hub database | rosa-89s85; current values added for sandbox3257 |
| [rhdh-vault-eso](rhdh-vault-eso/README.md) | Hub secrets from Vault through External Secrets | rosa-89s85 |
| [rhdh-catalog-refresh](rhdh-catalog-refresh/README.md) | Forcing the catalog to re-read a template | rosa-89s85 |
| [`tools/ldap`](../tools/ldap/README.md) | The stand-in OpenLDAP and the demo people | both |

`rosa-89s85` no longer exists. A page last proven there is still the right procedure; its URLs, hostnames and Helm revision numbers are history.

## Two repos

| Repo | Holds |
|---|---|
| `rmallam/RHDH` (this one) | Operator installs for CNPG, test tools (`tools/`), the Dev Spaces ingress shard, the standalone Hub chart, golden-path templates, these runbooks |
| `rmallam/rhdh-platform-gitops` | Custom resources only: CNPG `Cluster`, mesh, `CheCluster`, `Backstage`. This is what the current cluster is deployed from |

Both repos contain a `charts/developer-hub`. The live Hub comes from `rhdh-platform-gitops`. The copy here is the older standalone path and its `values-demo.yaml` still targets `rosa-89s85`.

## Conventions

- Every page opens with one bold **Update this file when…** line. Follow it.
- A fix goes in the page's **Known issues** table with the date and the error text as it appeared.
- **Production deltas** tables list what a customer install changes. They are the only place lab shortcuts are allowed to be described as acceptable.
- No real secret values or tokens. Key names and placeholders only.
- A version or status that was not read from a running cluster is marked as a target, not as fact.

## Run all doc tests

```bash
for t in docs/*/tests/test-*.sh; do "$t" >/dev/null && echo "pass $t" || echo "FAIL $t"; done
```
