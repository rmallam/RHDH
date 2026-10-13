#!/usr/bin/env bash
# Unit: the mesh runbook has the live pins, the enrolment labels and the
# list of things that are not proven yet.
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
need "Update this file when a workload is enrolled"
need "servicemeshoperator3.v3.4.3"
need "profile: ambient"
need "trustedZtunnelNamespace"
need "sailoperator.io/v1"
need "istio.io/dataplane-mode: ambient"
need "istio-discovery: enabled"
need "## Not proven yet"
need "routingViaHost"
need "enableUserWorkload: true"
need "mode: STRICT"
need "istio-waypoint"
need "## Production deltas"
need "## Known issues"
if [ "$fail" -ne 0 ]; then
  echo "Service Mesh docs tests failed"
  exit 1
fi
echo "Service Mesh docs tests passed"
