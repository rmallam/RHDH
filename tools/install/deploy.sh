#!/usr/bin/env bash
# Install Jenkins, SonarQube, Vault (dev), and SaaS stubs; wire rhdh-secrets.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH

need() { command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 1; }; }
need oc
need python3
need openssl

rand() { openssl rand -base64 24 | tr -d '/+=' | cut -c1-24; }

ensure_ns() { oc get ns "$1" >/dev/null 2>&1 || oc create ns "$1"; }

ensure_secret_literal() {
  local ns="$1" name="$2" key="$3" val="$4"
  if oc -n "$ns" get secret "$name" >/dev/null 2>&1; then
    echo "secret $ns/$name exists"
    return
  fi
  oc -n "$ns" create secret generic "$name" --from-literal="$key=$val"
  echo "created secret $ns/$name"
}

echo "== apply jenkins =="
oc apply -k "$ROOT/tools/jenkins/base"

echo "== apply sonarqube =="
ensure_ns sonarqube
ensure_secret_literal sonarqube sonarqube-admin password "$(rand)"
oc apply -k "$ROOT/tools/sonarqube/base"

echo "== apply vault =="
ensure_ns vault
ensure_secret_literal vault vault-root token "$(rand)"
oc apply -k "$ROOT/tools/vault/base"

echo "== apply saas-stubs =="
oc apply -k "$ROOT/tools/saas-stubs/base"

echo "== wait (parallel) =="
# Jenkins DC can take several minutes (image + JVM).
oc -n jenkins rollout status dc/jenkins --timeout=600s || oc -n jenkins get pods &
oc -n sonarqube rollout status deploy/sonarqube --timeout=420s || oc -n sonarqube get pods &
oc -n vault rollout status deploy/vault --timeout=180s || oc -n vault get pods &
oc -n saas-stubs rollout status deploy/saas-stubs --timeout=180s || oc -n saas-stubs get pods &
wait

python3 "$ROOT/tools/install/wire-rhdh-secrets.py"

echo "Jenkins:    https://$(oc -n jenkins get route jenkins -o jsonpath='{.spec.host}')"
echo "SonarQube:  https://$(oc -n sonarqube get route sonarqube -o jsonpath='{.spec.host}')"
echo "Vault:      https://$(oc -n vault get route vault -o jsonpath='{.spec.host}')"
echo "SaaS stubs: https://$(oc -n saas-stubs get route saas-stubs -o jsonpath='{.spec.host}')"
echo "Admin Jenkins user is admin (password is the OpenShift template default). Tokens are in rhdh-secrets."
