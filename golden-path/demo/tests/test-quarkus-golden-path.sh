#!/usr/bin/env bash
# Unit: Quarkus template + skeleton include System/API/providesApis, Jenkins, Helm.
# System: render placeholders, javac HealthPayload, helm lint + mesh render.
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

T="$DIR/template-quarkus-golden-path.yaml"
S="$DIR/skeleton-quarkus-golden-path"
need "name: acme-quarkus-golden-path" "$T"
need "title: GitHub repository name" "$T"
need "required: [appName, githubOwner, systemName]" "$T"
need "publish:github" "$T"
need "steps['publish'].output.repoContentsUrl" "$T"
need "/dashboard/#/load-factory?url=" "$T"
need "skeleton-quarkus-golden-path" "$T"
need "template-quarkus-golden-path.yaml" "$DIR/location.yaml"
need "kind: System" "$S/catalog-info.yaml"
need "kind: API" "$S/catalog-info.yaml"
need "providesApis:" "$S/catalog-info.yaml"
need "type: service" "$T"
need "type: service" "$S/catalog-info.yaml"
need "jenkins.io/job-full-name" "$S/catalog-info.yaml"
need "acme.io/mesh: ambient" "$S/catalog-info.yaml"
need "backstage.io/source-location: url:https://github.com/" "$S/catalog-info.yaml"
need "defaultContainer 'jdk'" "$S/Jenkinsfile"
need "mvn -q -DskipITs test" "$S/Jenkinsfile"
need "kind: HTTPRoute" "$S/chart/templates/httproute.yaml"
need "name: platform-ingressgateway" "$S/chart/values.yaml"
need "className: istio" "$S/chart/values.yaml"
need "mode: Terminate" "$S/chart/templates/gateway.yaml"
need "ISTIO_MUTUAL" "$S/chart/templates/destination-rule.yaml"
need "quarkus-rest" "$S/pom.xml"
need "@Path(\"/health\")" "$S/src/main/java/org/acme/HealthResource.java"
need "@Path(\"/api\")" "$S/src/main/java/org/acme/ApiResource.java"
need "clusterBaseDomain" "$T"

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
  echo "Quarkus golden-path template tests failed"
  exit 1
fi

WORKDIR="$(mktemp -d)"
python3 - "$S" "$WORKDIR" <<'PY'
import pathlib, shutil, re, sys
src, dst = map(pathlib.Path, sys.argv[1:])
shutil.copytree(src, dst, dirs_exist_ok=True)
vals = {
    "appName": "demo-quarkus-gp",
    "appDescription": "test render",
    "githubOwner": "rmallam",
    "systemName": "acme-demo",
    "systemDescription": "demo product",
    "port": "8080",
    "targetNamespace": "demo-dev",
    "clusterBaseDomain": "apps.example.test",
    "sonarHostUrl": "http://sonarqube.sonarqube.svc:9000",
    "sonarProjectKey": "demo-quarkus-gp",
    "devSpacesBaseUrl": "https://devspaces.example.test",
}
pat = re.compile(r"\$\{\{\s*values\.(\w+)\s*\}\}")
for p in dst.rglob("*"):
    if p.is_file():
        text = p.read_text()
        p.write_text(pat.sub(lambda m: vals[m.group(1)], text))
print("rendered", dst)
PY

if command -v javac >/dev/null 2>&1 && command -v java >/dev/null 2>&1; then
  OUT="$WORKDIR/out"
  mkdir -p "$OUT"
  javac -d "$OUT" "$WORKDIR/src/main/java/org/acme/HealthPayload.java"
  cat >"$WORKDIR/Check.java" <<'JAVA'
import org.acme.HealthPayload;
public class Check {
  public static void main(String[] args) {
    var body = HealthPayload.ok("demo-quarkus-gp");
    if (!"ok".equals(body.get("status"))) throw new RuntimeException(String.valueOf(body));
    if (!"demo-quarkus-gp".equals(body.get("app"))) throw new RuntimeException(String.valueOf(body));
    System.out.println("OK  javac HealthPayload");
  }
}
JAVA
  javac -cp "$OUT" -d "$OUT" "$WORKDIR/Check.java"
  java -cp "$OUT" Check
else
  echo "OK  javac not installed — skipped HealthPayload compile"
fi

if command -v mvn >/dev/null 2>&1; then
  (cd "$WORKDIR" && mvn -q -DskipITs test)
  echo "OK  mvn test"
else
  echo "OK  mvn not installed — skipped Quarkus surefire"
fi

helm lint "$WORKDIR/chart"

MESH="$(mktemp)"
NOMESH="$(mktemp)"
trap 'rm -rf "$WORKDIR"; rm -f "$MESH" "$NOMESH"' EXIT
helm template demo-quarkus-gp "$WORKDIR/chart" -n demo-dev >"$MESH"
helm template demo-quarkus-gp "$WORKDIR/chart" -n demo-dev --set mesh.enabled=false --set route.enabled=true >"$NOMESH"

mesh_need() {
  if grep -q "$1" "$MESH"; then
    echo "OK  mesh render $1"
  else
    echo "FAIL mesh render missing $1"
    fail=1
  fi
}
mesh_need "kind: AuthorizationPolicy"
mesh_need "name: demo-quarkus-gp-deny-all"
mesh_need "kind: HTTPRoute"
mesh_need "platform-ingressgateway"
mesh_need "kind: Gateway"
mesh_need "gatewayClassName: istio"
mesh_need "mode: Terminate"
mesh_need "mode: ISTIO_MUTUAL"
mesh_need "demo-quarkus-gp-demo-dev.apps.example.test"
mesh_need "QUARKUS_HTTP_PORT"
mesh_need "sidecar.istio.io/inject: \"false\""

if grep -q "kind: VirtualService" "$MESH"; then
  echo "FAIL mesh render must not emit VirtualService; use HTTPRoute"
  fail=1
fi
if grep -q "kind: PeerAuthentication" "$MESH"; then
  echo "FAIL mesh render must not emit PeerAuthentication; it is namespace/mesh scoped"
  fail=1
fi
if ! awk '/kind: Gateway$/{c=1} c&&/namespace: istio-system/{found=1} END{exit !found}' "$MESH"; then
  echo "FAIL Gateway API Gateway must live in istio-system with the ingressgateway"
  fail=1
fi
if ! grep -q "kind: Route" "$NOMESH"; then
  echo "FAIL mesh-off render missing app Route"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "Quarkus golden-path tests failed"
  exit 1
fi
echo "Quarkus golden-path template tests passed"
