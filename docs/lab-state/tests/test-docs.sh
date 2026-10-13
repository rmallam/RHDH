#!/usr/bin/env bash
# Unit: the lab-state page names the current cluster, the installed CSVs
# and the things that are in git but not deployed.
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
need "Update this file after every rebuild"
need "sandbox3257"
need "rhdh-operator.v1.10.5"
need "servicemeshoperator3.v3.4.3"
need "kiali-operator.v2.27.5"
need "devspacesoperator.v3.30.2"
need "cloudnative-pg.v1.30.1"
need "PostgreSQL 18.6"
need "In the repos but not on the cluster"
need "Lab-only settings"
need "Rebuild order on a fresh cluster"
need "gitops-controller-admin.yaml"
if [ "$fail" -ne 0 ]; then
  echo "Lab state docs tests failed"
  exit 1
fi
echo "Lab state docs tests passed"
