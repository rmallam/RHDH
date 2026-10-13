#!/usr/bin/env bash
# Unit: the Dev Spaces runbook has the live pins, the shard wiring and the
# storage caveat.
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
need "Update this file when a workspace fails to start"
need "devspacesoperator.v3.30.2"
need "<username>-devspaces"
need "maxNumberOfRunningWorkspacesPerUser"
need "container-build"
need "pvcStrategy"
need "ReadWriteOnce"
need "ingress.openshift.io/shard"
need "default-exclude-shard.yaml"
need "oc apply -k tools/ingress-shard"
need "## Production deltas"
need "## Known issues"
if [ "$fail" -ne 0 ]; then
  echo "Dev Spaces docs tests failed"
  exit 1
fi
echo "Dev Spaces docs tests passed"
