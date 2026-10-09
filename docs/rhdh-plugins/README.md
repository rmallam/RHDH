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
| [bitbucket](bitbucket.md) | broken | integrations + catalog/scaffolder modules | Missing `@backstage/plugin-bitbucket-cloud-common` |
| [ldap](ldap.md) | working | catalog provider | Join key = email |
| [microsoft-auth](microsoft-auth.md) | working | sign-in | Entra; not a software-catalog tab |
| [api-docs](api-docs.md) | disabled | API entities | Off in `values-demo.yaml` |
| [msgraph](msgraph.md) | disabled | catalog provider | LDAP is the org source |
| [keycloak](keycloak.md) | disabled | catalog provider | Not used with Entra |

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
