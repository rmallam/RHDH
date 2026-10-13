# Plugin inventory

`plugins-oci.txt` is the customer pin list (spreadsheet data.xls v.2) plus extras this platform loads. Kubernetes and LDAP **match the spreadsheet** but stay bundled in the RHDH image, so they are comments only. Everything else with an overlay is an `oci://` line.

| Needed (HLD) | Plugin | Pin | In `plugins-oci.txt`? |
|---|---|---|---|
| Must — CI visibility | Jenkins / CloudBees FE + BE + scaffolder | 0.30.0 / 0.27.0 / 0.20.0 | Yes (3 OCI) |
| Must — GitOps | Argo CD community UI + backend + scaffolder | 2.8.1 / 1.4.0 / 1.8.1 | Yes (3 OCI; sheet FE was 2.8.0) |
| Must — quality | SonarQube scaffolder + utils + UI | 2.15.0 / 4.1.2 / 1.1.0 / 1.1.1 | Yes |
| Must — security | Snyk | 2.5.10 | Yes (self-exported) |
| Must — artefacts | Artifactory / JFrog | 1.28.0 | Yes |
| Must — work items | Jira | 2.14.0 | Yes |
| Must — incidents | PagerDuty FE + BE + processor + scaffolder | 0.19.0 / 0.12.0 / 0.3.10 / 0.2.9 | Yes (4 OCI) |
| Must — clusters | Kubernetes backend + scaffolder + Topology | 0.21.2 / 2.17.1 | No — bundled |
| Must — SCM | Bitbucket Cloud + Server catalog | 0.5.9 | Yes (2 OCI) |
| Must — docs | TechDocs | Bundled | No |
| Must — APIs | API docs (OpenAPI viewer) | Bundled | No |
| Must — identity | Microsoft Entra + MS Graph + Keycloak + **LDAP** | LDAP 0.12.3 | LDAP comment only — bundled |
| Must — authz | RBAC frontend + backend | Bundled | No |
| Must — secrets | HashiCorp Vault (LIST-only K/V v2) | FE 0.25.0 / BE 0.27.0 | Yes (live chart still `pr_1225`) |
| Must — change / CMDB | ServiceNow (sheet TBD) | UI/BE 1.10.0 + scaffolder 2.15.1 | Yes (3 artifacts) |
| Must — APM | Dynatrace entity card + DQL | 10.17.0 + DQL 2.7.0 | Yes |
| Should — API catalog | IBM API Connect | 1.0.0 (chart still 1.0.3) | Yes |
| Optional | DX (Developer Experience) | 1.0.0 | Comment — no RH overlay |
| Optional / Pipelines | Tekton | 3.33.3 | Yes (extra) |
| Optional / mesh | Kiali | FE 1.50.2 / BE 1.29.1 | Yes (extra) |
| Secondary SCM | GitHub actions/issues + scaffolder | Bundled | No |
| UX | Notifications + Signals | Bundled | No |

Also mirror, separately from this table:

- **RHDH hub image** — carries every `./dynamic-plugins/dist/…` row
- **`oci://registry.access.redhat.com/rhdh/plugin-catalog-index:1.10`** — Red Hat GA/TP index

## Tag pin (confirm before freeze)

New OCI lines use **RHDH 1.10 / Backstage 1.49.4** tags from the Dynamic Plugins Reference where Red Hat publishes them. Vault spreadsheet pins are `0.27.0` / `0.25.0` — run `skopeo list-tags` on GHCR if those `bs_` tags are missing (live chart still uses `pr_1225`). IBM APIC spreadsheet pin is `1.0.0`. Argo CD frontend spreadsheet said `2.8.0`; published tag is `2.8.1`. DX 1.0.0 has no overlay (`@get-dx/backstage-plugin` on npm).

Secrets for these four integrations: `manifests/plugin-secrets.example.yaml`. Merge into `rhdh-secrets`. Vault token must be **LIST-only**.

## Still not an RHDH plugin

| Need | How it is covered today |
|---|---|
| Splunk | Namespace annotations + cluster logging — no Splunk plugin in this list |
| Lightspeed / MCP | Separate product decision (DR-15) |
