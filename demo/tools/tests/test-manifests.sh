#!/usr/bin/env bash
# Unit: stub handler. System: kustomize build + helm demo overlay URLs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
fail=0

python3 "$ROOT/demo/tools/tests/test-stubs.py" || fail=1

need() { command -v "$1" >/dev/null || { echo "missing $1" >&2; fail=1; }; }
need oc
need helm

for path in jenkins sonarqube vault saas-stubs cnpg; do
  echo "== kustomize $path =="
  if ! oc kustomize "$ROOT/components/$path/base" >/tmp/tools-$path.yaml; then
    echo "FAIL kustomize $path"
    fail=1
    continue
  fi
  kinds="Namespace"
  [ "$path" != "cnpg" ] && kinds="$kinds Service"
  for kind in $kinds; do
    if grep -q "kind: $kind" "/tmp/tools-$path.yaml"; then
      echo "OK  $path $kind"
    else
      echo "FAIL $path missing $kind"
      fail=1
    fi
  done
done

grep -q "kind: DeploymentConfig" /tmp/tools-jenkins.yaml || { echo "FAIL jenkins DC"; fail=1; }
grep -q "sonarqube:lts-community" /tmp/tools-sonarqube.yaml || { echo "FAIL sonar image"; fail=1; }
grep -q "vault:1.18.5" /tmp/tools-vault.yaml || { echo "FAIL vault image"; fail=1; }
grep -q "saas-stubs listening" /tmp/tools-saas-stubs.yaml || grep -q "server.py" /tmp/tools-saas-stubs.yaml || { echo "FAIL stub server"; fail=1; }
grep -q "name: cloudnative-pg" /tmp/tools-cnpg.yaml || { echo "FAIL cnpg subscription"; fail=1; }
grep -q "channel: stable-v1" /tmp/tools-cnpg.yaml || { echo "FAIL cnpg channel"; fail=1; }

DEMO="$(mktemp)"
helm template rhdh "$ROOT/charts/developer-hub" --namespace rhdh \
  -f "$ROOT/charts/developer-hub/values.yaml" \
  -f "$ROOT/charts/developer-hub/values-demo.yaml" >"$DEMO"

for pat in \
  "http://jenkins.jenkins.svc" \
  "http://sonarqube.sonarqube.svc:9000" \
  "http://saas-stubs.saas-stubs.svc:8080" \
  "http://vault.vault.svc:8200"
do
  if grep -q "$pat" "$DEMO"; then
    echo "OK  helm $pat"
  else
    echo "FAIL helm missing $pat"
    fail=1
  fi
done

if grep -A2 "backstage-community-plugin-vault" "$DEMO" | grep -q "disabled: false"; then
  echo "OK  vault plugin enabled"
else
  echo "FAIL vault plugin should be enabled"
  fail=1
fi
if grep -q "kind: ExternalSecret" "$DEMO"; then
  echo "OK  helm ExternalSecret"
else
  echo "FAIL helm missing ExternalSecret"
  fail=1
fi

rm -f "$DEMO"
if [ "$fail" -ne 0 ]; then
  echo "tool manifest tests failed"
  exit 1
fi
echo "tool manifest tests passed"
