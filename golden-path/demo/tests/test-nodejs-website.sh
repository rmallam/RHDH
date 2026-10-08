#!/usr/bin/env bash
# Unit: website template EntityPicker + consumesApis/dependsOn.
# System: render placeholders, npm test, helm lint + mesh render.
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

T="$DIR/template-nodejs-website.yaml"
S="$DIR/skeleton-nodejs-website"
need "name: acme-nodejs-website" "$T"
need "ui:field: EntityPicker" "$T"
need "allowedKinds: [System]" "$T"
need "allowedKinds: [Component]" "$T"
need "allowedKinds: [API]" "$T"
need "spec.type: service" "$T"
need 'description: "Component (spec.type: service)' "$T"
need "parseEntityRef" "$T"
need "publish:github" "$T"
need "steps['publish'].output.repoContentsUrl" "$T"
need "/dashboard/#/load-factory?url=" "$T"
need "skeleton-nodejs-website" "$T"
need "template-nodejs-website.yaml" "$DIR/location.yaml"
need "type: website" "$S/catalog-info.yaml"
need "consumesApis:" "$S/catalog-info.yaml"
need "dependsOn:" "$S/catalog-info.yaml"
need "system: \${{ values.systemName }}" "$S/catalog-info.yaml"
need "jenkins.io/job-full-name" "$S/catalog-info.yaml"
need "acme.io/mesh: ambient" "$S/catalog-info.yaml"
need "backstage.io/source-location: url:https://github.com/" "$S/catalog-info.yaml"
need "BACKEND_URL" "$S/server.js"
need "fetchBackend" "$S/server.js"
need "defaultContainer 'nodejs'" "$S/Jenkinsfile"
need "kind: HTTPRoute" "$S/chart/templates/httproute.yaml"
need "BACKEND_URL" "$S/chart/templates/deployment.yaml"
need "backend:" "$S/chart/values.yaml"

if grep -q "publish:bitbucket" "$T"; then
  echo "FAIL template publishes to Bitbucket"
  fail=1
fi
if grep -E "remoteUrl \}\}/(blob|tree)/" "$T"; then
  echo "FAIL file/dir links must use repoContentsUrl (remoteUrl includes .git and 404s on GitHub)"
  fail=1
fi
if grep 'source-location:' "$S/catalog-info.yaml" | grep -q '\.git/'; then
  echo "FAIL source-location must not include .git in the GitHub path"
  fail=1
fi
if [ -f "$S/chart/templates/virtual-service.yaml" ]; then
  echo "FAIL greenfield chart must not ship VirtualService (use HTTPRoute)"
  fail=1
fi
if [ -f "$S/chart/templates/peer-authentication.yaml" ]; then
  echo "FAIL PeerAuthentication is namespace/mesh scoped (Kyverno), not per service"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "Node.js website template tests failed"
  exit 1
fi

WORKDIR="$(mktemp -d)"
python3 - "$S" "$WORKDIR" <<'PY'
import pathlib, shutil, re, sys
src, dst = map(pathlib.Path, sys.argv[1:])
shutil.copytree(src, dst, dirs_exist_ok=True)
vals = {
    "appName": "demo-node-web",
    "appDescription": "test website",
    "githubOwner": "rmallam",
    "systemName": "acme-demo",
    "backendServiceRef": "component:default/demo-quarkus-gp",
    "backendServiceName": "demo-quarkus-gp",
    "backendApiRef": "api:default/demo-quarkus-gp-api",
    "backendApiName": "demo-quarkus-gp-api",
    "backendUrl": "http://demo-quarkus-gp.demo-dev.svc:8080",
    "port": "3000",
    "targetNamespace": "demo-dev",
    "clusterBaseDomain": "apps.example.test",
    "sonarHostUrl": "http://sonarqube.sonarqube.svc:9000",
    "sonarProjectKey": "demo-node-web",
    "devSpacesBaseUrl": "https://devspaces.example.test",
}
pat = re.compile(r"\$\{\{\s*values\.(\w+)\s*\}\}")
for p in dst.rglob("*"):
    if p.is_file():
        text = p.read_text()
        p.write_text(pat.sub(lambda m: vals[m.group(1)], text))
print("rendered", dst)
PY

if grep -q "type: website" "$WORKDIR/catalog-info.yaml" \
  && grep -q "consumesApis:" "$WORKDIR/catalog-info.yaml" \
  && grep -q "api:default/demo-quarkus-gp-api" "$WORKDIR/catalog-info.yaml" \
  && grep -q "component:default/demo-quarkus-gp" "$WORKDIR/catalog-info.yaml"; then
  echo "OK  rendered catalog relations"
else
  echo "FAIL rendered catalog missing website relations"
  fail=1
fi

(cd "$WORKDIR" && npm run lint && npm test)
helm lint "$WORKDIR/chart"

MESH="$(mktemp)"
trap 'rm -rf "$WORKDIR"; rm -f "$MESH"' EXIT
helm template demo-node-web "$WORKDIR/chart" -n demo-dev >"$MESH"

mesh_need() {
  if grep -q "$1" "$MESH"; then
    echo "OK  mesh render $1"
  else
    echo "FAIL mesh render missing $1"
    fail=1
  fi
}
mesh_need "kind: HTTPRoute"
mesh_need "platform-ingressgateway"
mesh_need "BACKEND_URL"
mesh_need "http://demo-quarkus-gp.demo-dev.svc:8080"
mesh_need "kind: AuthorizationPolicy"

if grep -q "kind: VirtualService" "$MESH"; then
  echo "FAIL mesh render must not emit VirtualService"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "Node.js website tests failed"
  exit 1
fi
echo "Node.js website template tests passed"
