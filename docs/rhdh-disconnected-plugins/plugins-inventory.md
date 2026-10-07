# Westpac plugin inventory

`plugins-oci.txt` is **only** what you `skopeo copy` off the internet. Jenkins, Kubernetes, Bitbucket, LDAP, and the rest **are required** and are already listed in `manifests/dynamic-plugins.yaml`. They live at `./dynamic-plugins/dist/…` inside the RHDH operand image, so they are **not** OCI lines.

| Needed for WNZL (HLD) | Plugin | How it is delivered | In `plugins-oci.txt`? |
|---|---|---|---|
| Must — CI visibility | Jenkins / CloudBees (frontend + backend) | Bundled in RHDH image | No — travels with the hub image (`oc-mirror`) |
| Must — GitOps | Argo CD UI + backend + scaffolder | OCI (GHCR overlay) | Yes (3 artifacts) |
| Must — quality | SonarQube (frontend + backend) | OCI | Yes |
| Must — security | Snyk | OCI | Yes |
| Must — artefacts | Artifactory / JFrog | OCI | Yes |
| Must — work items | Jira | OCI | Yes |
| Must — clusters | Kubernetes + Topology | Bundled | No |
| Must — SCM | Bitbucket Cloud + Server scaffolder | Bundled | No |
| Must — docs | TechDocs | Bundled | No |
| Must — APIs | API docs (OpenAPI viewer) | Bundled | No |
| Must — identity | Microsoft Entra + MS Graph + Keycloak org + **LDAP** | Bundled | No |
| Must — authz | RBAC frontend + backend | Bundled | No |
| Must — secrets | HashiCorp Vault (LIST-only K/V v2) | OCI | Yes (frontend + backend) |
| Must — change / CMDB | ServiceNow (scaffolder actions + UI + backend) | OCI | Yes (3 artifacts) |
| Must — APM | Dynatrace entity card + DQL | OCI | Yes (3 artifacts) |
| Should — API catalog | IBM API Connect (`apic-backstage`) | OCI | Yes |
| Optional / if they use Pipelines | Tekton | OCI | Yes |
| Secondary SCM | GitHub actions/issues + scaffolder | Bundled | No |
| UX | Notifications + Signals | Bundled | No |

Also mirror, separately from this table:

- **RHDH hub image** — carries every `./dynamic-plugins/dist/…` row
- **`oci://registry.access.redhat.com/rhdh/plugin-catalog-index:1.10`** — Red Hat GA/TP index

## Tag pin (confirm before freeze)

New OCI lines use **RHDH 1.10 / Backstage 1.49.4** tags from the Dynamic Plugins Reference where Red Hat publishes them. Vault is **not** in that extras table — run `skopeo list-tags` on GHCR and replace `bs_1.49.4__0.31.0` if the tag does not exist. IBM APIC may need the `!apic-backstage` subpath (see IBM docs). Dynatrace DQL overlay is currently tagged `bs_1.52.0__2.8.0`.

Secrets for these four integrations: `manifests/plugin-secrets.example.yaml`. Merge into `rhdh-secrets`. Vault token must be **LIST-only**.

## Still not an RHDH plugin

| Need | How it is covered today |
|---|---|
| Splunk | Namespace annotations + cluster logging — no Splunk plugin in this list |
| Lightspeed / MCP | Separate product decision (DR-15) |
