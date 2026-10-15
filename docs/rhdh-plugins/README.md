# RHDH plugin runbooks

What each Developer Hub plugin needs to light up, on this ROSA lab and in a customer install.

**Update this folder whenever a plugin fails or a fix lands.** Add the error under **Known issues**, then move it to **Fixed** with the change (chart path + Helm revision if live). The kitchen-sink entity `component:default/plugin-kitchen-sink` and the golden-path template `acme-plugin-kitchen-sink` are the fixtures used to prove a tab.

| Status | Meaning |
|---|---|
| working | Plugin loads; a tab or action succeeds against a real or stubbed backend |
| partial | Plugin loads; card is empty or stubbed until a matching object exists |
| broken | Module fails to load or a required secret/backend is missing |
| disabled | `enabled: false` in values (demo or production) |

## Lab status (ROSA rosa-89s85)

| Plugin | Status | Entity annotation / trigger | Notes |
|---|---|---|---|
| [kubernetes](kubernetes.md) + Topology | working | `backstage.io/kubernetes-id` | SA token automount + ClusterRole + metrics |
| [jenkins](jenkins.md) | partial | `jenkins.io/job-full-name` | In-cluster Jenkins; job must exist |
| [argocd](argocd.md) | working | `argocd/app-name` | Kitchen-sink points at `developer-hub` |
| [sonarqube](sonarqube.md) | partial | `sonarqube.org/project-key` | In-cluster Sonar; project must exist |
| [vault](vault.md) | working | `vault.io/secrets-path` | `-dev` Vault; `pr_1225` overlay |
| [snyk](snyk.md) | partial | `snyk.io/org-id` | Self-exported OCI; `mocked: true` on demo |
| [jira](jira.md) | working | `jira/project-key` | Demo stub returns DEMO issues; kitchen-sink `DEMO` |
| [artifactory](artifactory.md) | partial | `jfrog-artifactory/image-name` | SaaS stub |
| [servicenow](servicenow.md) | working | `servicenow.com/entity-id` | Demo stub returns INC tickets for `demo` |
| [dynatrace](dynatrace.md) | partial | `dynatrace.com/dynatrace-entity-id` | SaaS stub |
| [apic](apic.md) | partial | plugin catalog sync | SaaS stub |
| [techdocs](techdocs.md) | working | `backstage.io/techdocs-ref` | Local builder; needs `mkdocs.yml` |
| [tekton](tekton.md) | partial | same `kubernetes-id` + PipelineRuns | No Pipelines operator on this lab |
| [notifications](notifications.md) | working | none | In-product inbox |
| [github-scaffolder](github-scaffolder.md) | working | template `publish:github` | `GITHUB_TOKEN` in Vault. After a template Git push, [force catalog refresh](../rhdh-catalog-refresh/README.md) |
| [bitbucket](bitbucket.md) | broken (Cloud), partial (Server) | integrations + catalog/scaffolder modules | Cloud modules miss `@backstage/plugin-bitbucket-cloud-common`. Server modules load; no Bitbucket Server on the lab to test against |
| [ldap](ldap.md) | working | catalog provider | Join key = email |
| [microsoft-auth](microsoft-auth.md) | working | sign-in | Entra; not a software-catalog tab |
| [api-docs](api-docs.md) | disabled | API entities | Off in `values-demo.yaml` |
| [msgraph](msgraph.md) | disabled | catalog provider | LDAP is the org source |
| [keycloak](keycloak.md) | disabled | catalog provider | Not used with Entra |

## Installed on sandbox3257

The table above was recorded on `rosa-89s85`, with `saas-stubs` and SonarQube running. Neither is deployed on the current cluster ([lab state](../lab-state/README.md)). Jira, Dynatrace and ServiceNow now point at real developer tenants instead of the stubs (ServiceNow since 2026-10-15). APIC, Artifactory and SonarQube still have no backend there until those two Applications are applied.

Below is what the Hub pod actually holds: versions from `package.json` under `dynamic-plugins-root`, load result from the backend log, both read on 2026-10-14. The log only reports backend plugins, so a frontend-only plugin is marked n/a: installed, but not confirmed to render. **Target** is the pin in [`plugins-oci.txt`](../rhdh-disconnected-plugins/plugins-oci.txt). Where the two differ, git is ahead of the cluster.

| Plugin | Installed | Target | Backend loaded |
|---|---|---|---|
| LDAP catalog module | 0.12.3 (bundled) | 0.12.3 | yes — `Read 3 LDAP users and 3 LDAP groups` |
| Kubernetes backend | 0.21.2 (bundled) | 0.21.2 | yes |
| Kubernetes scaffolder module | bundled, **disabled** | 2.17.1 | no — enable it |
| Topology | 2.12.4 (bundled) | — | n/a (frontend) |
| Jenkins backend / frontend | 0.27.0 / 0.30.0 | same | yes |
| Jenkins scaffolder module | not installed | 0.20.0 | — |
| Argo CD frontend | 2.4.4 (`bs_1.45.3`) | 2.8.1 | n/a (frontend) |
| Argo CD backend | Roadie `argo-cd-backend` 4.6.0 (`bs_1.45.3`) | community `argocd-backend` 1.4.0 | yes |
| Argo CD scaffolder (Roadie) | 1.8.1 (`bs_1.45.3`) | 1.8.1 (`bs_1.49.4`) | yes |
| SonarQube frontend / backend | 0.21.0 / 0.15.0 (`bs_1.45.3`) | 1.1.0 / 1.1.1 | yes |
| SonarQube scaffolder module, scaffolder utils | not installed | 2.15.0, 4.1.2 | — |
| Vault frontend / backend | 0.19.0 / 0.21.0 (`pr_1225`) | 0.25.0 / 0.27.0 | yes |
| Jira | 2.14.0 | same | n/a (frontend) |
| Artifactory | 1.28.0 | same | n/a (frontend) |
| ServiceNow scaffolder / backend / frontend | 2.15.1 / 1.10.0 / 1.10.0 | same | yes |
| Dynatrace, DQL frontend / backend | 10.17.0, 2.7.0 / 2.7.0 | same | yes |
| Kiali frontend / backend | 1.50.2 / 1.29.1 | same | yes |
| Tekton | 3.33.3 (`bs_1.45.3`) | 3.33.3 | n/a (frontend) |
| IBM API Connect | 1.0.3 | 1.0.0 | yes |
| PagerDuty (4 packages) | not installed | 0.12.0, 0.3.10, 0.19.0, 0.2.9 | — |
| Snyk | not installed (private image) | 2.5.10 | — |
| Bitbucket Server catalog / scaffolder | 0.5.9 / 0.2.19 | catalog 0.5.9 | yes |
| Bitbucket Cloud catalog / scaffolder | 0.5.9 / 0.3.4 | catalog 0.5.9 | **no** — `Cannot find module '@backstage/plugin-bitbucket-cloud-common'` |
| TechDocs backend / frontend | 2.1.6 / 1.17.2 (bundled) | — | yes |
| Notifications, Signals | 0.6.3 / 0.5.15, 0.3.13 / 0.0.29 (bundled) | — | yes |
| GitHub scaffolder | 0.9.7 (bundled) | — | yes |

Six packages are still on the `bs_1.45.3` overlay, which was built for the previous RHDH release. They load on 1.10.5, but they are not the builds published for 1.10.

Also loaded, from the default RHDH 1.10 profile rather than from this chart: Lightspeed frontend and backend 2.8.7, Adoption Insights 0.8.2, the Segment analytics provider 1.27.0, Extensions 0.17.2, Quickstart, the global header and the dynamic home page. Disable the ones a customer does not want; Segment sends usage telemetry out of the cluster.

Regenerate both columns:

```bash
P=$(oc -n rhdh get pod -l rhdh.redhat.com/app=backstage-developer-hub -o name | head -1)

# name and version of every installed plugin
oc -n rhdh exec $P -c backstage-backend -- sh -c '
  for d in /opt/app-root/src/dynamic-plugins-root/*/; do
    n=$(grep -m1 "\"name\"" "$d/package.json" | sed "s/.*: *\"//;s/\".*//")
    v=$(grep -m1 "\"version\"" "$d/package.json" | sed "s/.*: *\"//;s/\".*//")
    echo "$n $v"
  done | sort'

# backend plugins that loaded, and those that did not
oc -n rhdh logs $P -c backstage-backend | grep -E "loaded dynamic backend plugin|error occurred while loading dynamic backend plugin"

# bundled plugins that were skipped because they are disabled
oc -n rhdh logs $P -c install-dynamic-plugins | grep "Skipping disabled"
```

A backend plugin that fails to load does **not** stop the Hub; it logs one error at startup and the feature is silently absent. A plugin image that cannot be **pulled** is different: `install-dynamic-plugins` fails closed and the Hub never starts.

## Shared requirements

1. Plugin `enabled: true` in `charts/developer-hub/values.yaml` (or overlay).
2. Package pin in `templates/configmap-dynamic-plugins.yaml`.
3. App-config or `pluginConfig` block (URLs, tokens as `${ENV}`).
4. Secret key in `secrets.keys` → Vault `secrets/data/rhdh/<key>` → ExternalSecret `rhdh-secrets`.
5. Catalog annotation on the Component (except auth/catalog-only plugins).
6. Some plugins also need **RHDH permission CSV** (Topology) or a **Kubernetes ClusterRole** (API reads).

Do **not** put tokens in values. Demo overlay (`values-demo.yaml`) points tools at in-cluster Services or `saas-stubs`.

## How to update after a fix

1. Reproduce on `component:default/plugin-kitchen-sink` or a repo from `acme-plugin-kitchen-sink`.
2. Patch the chart (values, app-config, RBAC, dynamic-plugins).
3. Add the error + fix to that plugin’s **Known issues**.
4. Flip the status table in this README.
5. `charts/developer-hub/tests/test-chart.sh` and `docs/rhdh-plugins/tests/test-plugin-docs.sh`.

## Fixtures

| Fixture | What it is |
|---|---|
| `charts/developer-hub/files/plugin-kitchen-sink.yaml` | Static catalog Component with every tab annotation |
| `golden-path/demo/template-plugin-kitchen-sink.yaml` | Scaffolder: GitHub repo + annotations + Dev Spaces factory URL |
