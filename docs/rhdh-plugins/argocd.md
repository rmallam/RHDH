# Argo CD

**Status:** working (kitchen-sink → live `developer-hub` app)

GitOps application card.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.argocd.enabled: true` |
| Packages | community frontend + roadie backend + scaffolder OCI |
| App-config | `argocd.appLocatorMethods` instance `url` + `token` |
| Catalog | `argocd/app-name` and optionally `argocd/app-namespace` |
| Reading allow | Argo server host in `app.readingAllow` |

## Secrets

`ARGOCD_URL`, `ARGOCD_TOKEN` (account token with `apiKey`, not an expired session)

Demo: OpenShift GitOps at
`https://openshift-gitops-server-openshift-gitops.apps.rosa.rosa-89s85.bhg0.p3.openshiftapps.com`

Kitchen-sink uses `argocd/app-name: developer-hub`, `argocd/app-namespace: openshift-gitops`.

## Known issues

| When | Error | Fix |
|---|---|---|
| earlier | 401 / empty apps | Argo session tokens expire; use `accounts.admin` login+apiKey and a durable account token in Vault |
