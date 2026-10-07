#!/usr/bin/env bash
# Unit: every Hub plugin has a runbook with Status + Required + Known issues.
# System: index table lists each runbook file.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

plugins=(
  kubernetes jenkins argocd sonarqube vault snyk jira artifactory
  servicenow dynatrace apic techdocs tekton notifications
  github-scaffolder bitbucket ldap microsoft-auth api-docs msgraph keycloak
)

for p in "${plugins[@]}"; do
  f="$DIR/${p}.md"
  if [ ! -f "$f" ]; then
    echo "FAIL missing $f"
    fail=1
    continue
  fi
  for heading in '**Status:**' '## Required' '## Known issues'; do
    if ! grep -Fq "$heading" "$f"; then
      echo "FAIL $p.md missing $heading"
      fail=1
    fi
  done
  echo "OK  $p.md"
done

for p in "${plugins[@]}"; do
  if ! grep -q "(${p}.md)" "$DIR/README.md"; then
    echo "FAIL README missing link to ${p}.md"
    fail=1
  fi
done

grep -q "Update this folder whenever a plugin fails" "$DIR/README.md" || {
  echo "FAIL README missing update rule"
  fail=1
}

if [ "$fail" -ne 0 ]; then
  echo "Plugin docs tests failed"
  exit 1
fi
echo "Plugin docs tests passed"
