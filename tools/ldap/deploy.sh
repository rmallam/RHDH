#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"

oc apply -f "$ROOT/namespace.yaml"

if ! oc -n ldap get secret openldap-admin >/dev/null 2>&1; then
  pass="$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)"
  oc -n ldap create secret generic openldap-admin \
    --from-literal=LDAP_ADMIN_PASSWORD="$pass"
  echo "created secret ldap/openldap-admin"
else
  echo "secret ldap/openldap-admin already exists"
fi

oc apply -k "$ROOT"
# Bitnami OpenLDAP image runs as UID 1001
oc adm policy add-scc-to-user anyuid -z openldap -n ldap
oc apply -k "$ROOT"
oc -n ldap rollout status deploy/openldap --timeout=240s
echo "LDAP is up at openldap.ldap.svc:389 (base dc=acme,dc=demo)"
