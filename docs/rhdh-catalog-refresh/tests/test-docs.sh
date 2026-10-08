#!/usr/bin/env bash
# Unit: catalog-refresh runbook has the live Location URLs and the force-refresh API.
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
need "POST /api/catalog/refresh"
need "api/auth/guest/refresh"
need "acme-nodejs-golden-path"
need "acme-plugin-kitchen-sink"
need "raw.githubusercontent.com/rmallam/RHDH"
need "template-nodejs-golden-path.yaml"
need "catalog.entity.refresh"
need "backstage-backend"
need "GitHub repository"
need "/f?url="
need "devfilePath=devfile.yaml"
if [ "$fail" -ne 0 ]; then
  echo "Catalog refresh docs tests failed"
  exit 1
fi
echo "Catalog refresh docs tests passed"
