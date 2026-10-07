# Jenkins

**Status:** partial (plugin + in-cluster Jenkins; job must exist)

CI card on the Component.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.jenkins.enabled: true` |
| Packages | community jenkins frontend + backend OCI (`bs_1.49.4`) |
| App-config | `jenkins.instances[]` (`baseUrl`, `username`, `apiKey`) |
| Proxy | `/jenkins/api` → Jenkins with `Basic ${JENKINS_BASIC_AUTH_B64}` |
| Catalog | `jenkins.io/job-full-name: <folder/job>` |

## Secrets

`JENKINS_BASE_URL`, `JENKINS_USERNAME`, `JENKINS_API_TOKEN`, `JENKINS_BASIC_AUTH_B64`

Demo overlay uses `http://jenkins.jenkins.svc`. UI: https://jenkins-jenkins.apps.rosa.rosa-89s85.bhg0.p3.openshiftapps.com

## Known issues

| When | Error | Fix |
|---|---|---|
| — | Empty CI card | Create a Jenkins job whose full name matches the annotation (kitchen-sink: `demo/plugin-kitchen-sink`) |
