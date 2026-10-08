# ${{ values.appName }}

${{ values.appDescription }}

## Pipeline

Jenkinsfile stages: **Install → Lint → Unit tests → SonarQube → Helm lint**.

Point a Jenkins job named `demo/${{ values.appName }}` at this repo. Set credential `SONAR_TOKEN` to run the scanner against `${{ values.sonarHostUrl }}`.

## Deploy

```bash
helm upgrade --install ${{ values.appName }} chart -n ${{ values.targetNamespace }}
```

The chart labels pods `backstage.io/kubernetes-id=${{ values.appName }}` for Topology.

## Dev Spaces

${{ values.devSpacesBaseUrl }}#https://github.com/${{ values.githubOwner }}/${{ values.appName }}?new&devfilePath=devfile.yaml
