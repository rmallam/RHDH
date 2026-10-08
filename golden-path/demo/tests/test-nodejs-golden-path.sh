#!/usr/bin/env bash
# Unit: template + skeleton include Jenkins, Helm, Sonar, tests, Dev Spaces.
# System: render placeholders, npm test, helm lint.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
need() {
  if grep -Fq "$1" "$2"; then
    echo "OK  $1"
  else
    echo "FAIL missing $1 in $2"
    fail=1
  fi
}

T="$DIR/template-nodejs-golden-path.yaml"
S="$DIR/skeleton-nodejs-golden-path"
need "name: acme-nodejs-golden-path" "$T"
need "title: GitHub repository name" "$T"
need "required: [appName, githubOwner]" "$T"
need "publish:github" "$T"
need "title: GitHub repository" "$T"
need "steps['publish'].output.remoteUrl" "$T"
need "/dashboard/#/load-factory?url=" "$T"
need "title: Helm chart" "$T"
need "title: Jenkinsfile" "$T"
need "title: OpenShift project" "$T"
need "skeleton-nodejs-golden-path" "$T"
need "template-nodejs-golden-path.yaml" "$DIR/location.yaml"
need "stage('SonarQube')" "$S/Jenkinsfile"
need "stage('Helm lint')" "$S/Jenkinsfile"
need "helm lint chart" "$S/Jenkinsfile"
need "sonar.projectKey" "$S/sonar-project.properties"
need "kind: Deployment" "$S/chart/templates/deployment.yaml"
need "backstage.io/kubernetes-id" "$S/chart/templates/_helpers.tpl"
need "jenkins.io/job-full-name" "$S/catalog-info.yaml"
need "sonarqube.org/project-key" "$S/catalog-info.yaml"
need "acme.io/helm-chart" "$S/catalog-info.yaml"
need "acme.io/devspaces-factory-url" "$S/catalog-info.yaml"

if grep -q "publish:bitbucket" "$T"; then
  echo "FAIL template publishes to Bitbucket"
  fail=1
fi
if grep -q "/f?url=" "$T"; then
  echo "FAIL template still uses Dev Spaces /f factory path (404 on this cluster)"
  fail=1
fi
if grep -q 'url: https://github.com/\${{ parameters.githubOwner }}' "$T"; then
  echo "FAIL output links must use publish remoteUrl (parameters are empty on this Hub)"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "Node.js golden-path template tests failed"
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
python3 - "$S" "$WORKDIR" <<'PY'
import pathlib, shutil, re, sys
src, dst = map(pathlib.Path, sys.argv[1:])
shutil.copytree(src, dst, dirs_exist_ok=True)
vals = {
    "appName": "demo-node-gp",
    "appDescription": "test render",
    "githubOwner": "rmallam",
    "port": "3000",
    "targetNamespace": "demo-dev",
    "sonarHostUrl": "http://sonarqube.sonarqube.svc:9000",
    "sonarProjectKey": "demo-node-gp",
    "devSpacesBaseUrl": "https://devspaces.example.test",
}
pat = re.compile(r"\$\{\{\s*values\.(\w+)\s*\}\}")
for p in dst.rglob("*"):
    if p.is_file():
        text = p.read_text()
        p.write_text(pat.sub(lambda m: vals[m.group(1)], text))
print("rendered", dst)
PY

(cd "$WORKDIR" && npm run lint && npm test)
helm lint "$WORKDIR/chart"
echo "Node.js golden-path template tests passed"
