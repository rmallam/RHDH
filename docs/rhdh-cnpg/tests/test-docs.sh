#!/usr/bin/env bash
# Unit: reuse playbook has the live pins and the install order.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
F="$DIR/README.md"
fail=0
need() {
  if grep -Fq "$1" "$F"; then
    echo "OK  $1"
  else
    echo "FAIL missing $1"
    fail=1
  fi
}
need "cloudnative-pg"
need "stable-v1"
need "cnpg-system"
need "rhdh-pg"
need "rhdh-pg-app"
need "enableLocalDb: false"
need "pluginDivisionMode: schema"
need "POSTGRES_HOST"
need "oc apply -k components/cnpg/base"
need "values-demo.yaml"
if [ "$fail" -ne 0 ]; then
  echo "CNPG docs tests failed"
  exit 1
fi
echo "CNPG docs tests passed"
