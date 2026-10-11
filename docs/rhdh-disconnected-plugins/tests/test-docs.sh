#!/usr/bin/env bash
# Unit: plugins-oci.txt pins match the customer spreadsheet (data.xls v.2)
# plus RHDH 1.10 / Backstage 1.49.4 overlay names.
# System: every active oci:// line is a well-formed GHCR overlay URL the
#         mirror script can parse; inventory table still names the file.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$DIR/plugins-oci.txt"
INV="$DIR/plugins-inventory.md"
fail=0

need() {
  if grep -Fq "$1" "$LIST"; then
    echo "OK  $1"
  else
    echo "FAIL missing $1"
    fail=1
  fi
}

# Spreadsheet rows 1–15 (plugin + version). Kubernetes/LDAP/DX are comments.
need "backstage-plugin-catalog-backend-module-bitbucket-cloud:bs_1.49.4__0.5.9"
need "backstage-plugin-catalog-backend-module-bitbucket-server:bs_1.49.4__0.5.9"
need "Kubernetes Backend 0.21.2"
need "Kubernetes Scaffolder Module 2.17.1"
need "backstage-community-plugin-scaffolder-backend-module-sonarqube:bs_1.49.4__2.15.0"
need "roadiehq-scaffolder-backend-module-utils:bs_1.49.4__4.1.2"
need "rhdh-plugin-snyk:bs_1.49.4__2.5.10"
need "roadiehq-backstage-plugin-jira:bs_1.49.4__2.14.0"
need "backstage-community-plugin-jfrog-artifactory:bs_1.49.4__1.28.0"
need "backstage-community-plugin-jenkins-backend:bs_1.49.4__0.27.0"
need "backstage-community-plugin-jenkins:bs_1.49.4__0.30.0"
need "backstage-community-plugin-scaffolder-backend-module-jenkins:bs_1.49.4__0.20.0"
need "pagerduty-backstage-plugin-backend:bs_1.49.4__0.12.0"
need "pagerduty-backstage-plugin-entity-processor:bs_1.49.4__0.3.10"
need "pagerduty-backstage-plugin:bs_1.49.4__0.19.0"
need "pagerduty-backstage-plugin-scaffolder-actions:bs_1.49.4__0.2.9"
need "backstage-community-plugin-vault-backend:bs_1.49.4__0.27.0"
need "backstage-community-plugin-vault:bs_1.49.4__0.25.0"
need "backstage-community-plugin-argocd-backend:bs_1.49.4__1.4.0"
need "backstage-community-plugin-argocd:bs_1.49.4__2.8.1"
need "backstage-community-plugin-dynatrace:bs_1.49.4__10.17.0"
need "apic-backstage:bs_1.49.4__1.0.0"
need "DX (Developer Experience) 1.0.0"
need "LDAP Catalog Backend 0.12.3"

# Retired pins must not stay as active mirror lines
if grep -E '^oci://' "$LIST" | grep -E '4\.6\.0|2\.4\.4|0\.21\.0|0\.15\.0|0\.31\.0' >/dev/null; then
  echo "FAIL retired overlay tag still active"
  fail=1
else
  echo "OK  retired overlay tags removed"
fi

# System: mirror script only copies active oci:// lines
while IFS= read -r line; do
  case "$line" in
    oci://ghcr.io/*:bs_*__*) echo "OK  url $line" ;;
    *)
      echo "FAIL bad oci line: $line"
      fail=1
      ;;
  esac
done < <(grep -E '^oci://' "$LIST")

count="$(grep -cE '^oci://' "$LIST")"
if [ "$count" -ge 24 ]; then
  echo "OK  $count active OCI lines"
else
  echo "FAIL expected >=24 active OCI lines, got $count"
  fail=1
fi

if grep -Fq "plugins-oci.txt" "$INV" && grep -Fq "0.5.9" "$INV"; then
  echo "OK  inventory lists spreadsheet pins"
else
  echo "FAIL inventory missing plugins-oci.txt / 0.5.9"
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  echo "Disconnected-plugin docs tests failed"
  exit 1
fi
echo "Disconnected-plugin docs tests passed"
