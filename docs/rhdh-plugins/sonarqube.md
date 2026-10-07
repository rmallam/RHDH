# SonarQube

**Status:** partial (plugin + in-cluster Sonar; project must exist)

Quality-gate card.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.sonarqube.enabled: true` |
| Packages | community sonarqube frontend + backend OCI |
| App-config | `sonarqube.baseUrl`, `apiKey`, `authType: Bearer` |
| Catalog | `sonarqube.org/project-key: <key>` |

## Secrets

`SONARQUBE_BASE_URL`, `SONARQUBE_API_KEY`

Demo: `http://sonarqube.sonarqube.svc:9000`  
UI: https://sonarqube-sonarqube.apps.rosa.rosa-89s85.bhg0.p3.openshiftapps.com

Kitchen-sink key: `demo-plugin-kitchen-sink`.

## Known issues

| When | Error | Fix |
|---|---|---|
| — | Empty / 404 project | Create the Sonar project with that key or change the annotation |
