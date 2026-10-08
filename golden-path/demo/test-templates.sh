#!/usr/bin/env bash
# Unit test: namespace Dev Spaces template is present and wired into the location.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
fail=0
need() {
  if grep -q "$1" "$2"; then
    echo "OK  $1"
  else
    echo "FAIL missing $1 in $2"
    fail=1
  fi
}
T="$DIR/template-open-devspaces-namespace.yaml"
need "name: acme-open-devspaces-namespace" "$T"
need "workspaceNamespace" "$T"
need "namespace=" "$T"
need "Does not provision a namespace" "$T"
need "template-open-devspaces-namespace.yaml" "$DIR/location.yaml"
need "template-plugin-kitchen-sink.yaml" "$DIR/location.yaml"
need "template-nodejs-golden-path.yaml" "$DIR/location.yaml"
need "template-quarkus-golden-path.yaml" "$DIR/location.yaml"
need "template-nodejs-website.yaml" "$DIR/location.yaml"
if [ "$fail" -ne 0 ]; then
  echo "Template tests failed"
  exit 1
fi
echo "Template tests passed"
