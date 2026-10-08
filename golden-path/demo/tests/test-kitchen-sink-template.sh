#!/usr/bin/env bash
# Unit: kitchen-sink template + skeleton have working-plugin annotations and a Dev Spaces URL.
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
need() {
  if grep -Fq "$1" "$2"; then
    echo "OK  $1"
  else
    echo "FAIL missing $1 in $2"
    fail=1
  fi
}

T="$DIR/template-plugin-kitchen-sink.yaml"
S="$DIR/skeleton-plugin-kitchen-sink/catalog-info.yaml"
need "name: acme-plugin-kitchen-sink" "$T"
need "publish:github" "$T"
need "catalog:register" "$T"
need "steps['publish'].output.remoteUrl" "$T"
need "/dashboard/#/load-factory?url=" "$T"
need "title: GitHub repository" "$T"
need "skeleton-plugin-kitchen-sink" "$T"
need "template-plugin-kitchen-sink.yaml" "$DIR/location.yaml"

for ann in \
  "backstage.io/techdocs-ref" \
  "jenkins.io/job-full-name" \
  "sonarqube.org/project-key" \
  "argocd/app-name" \
  "backstage.io/kubernetes-id" \
  "vault.io/secrets-path" \
  "jira/project-key" \
  "snyk.io/org-id" \
  "servicenow.com/entity-id" \
  "jfrog-artifactory/image-name" \
  "dynatrace.com/dynatrace-entity-id" \
  "acme.io/devspaces-factory-url"
do
  need "$ann" "$S"
done

# Bitbucket must not be the publish target while that plugin is broken.
if grep -q "publish:bitbucket" "$T"; then
  echo "FAIL template still publishes to Bitbucket"
  fail=1
fi

need "schemaVersion: 2.2.2" "$DIR/skeleton-plugin-kitchen-sink/devfile.yaml"
need "site_name:" "$DIR/skeleton-plugin-kitchen-sink/mkdocs.yml"

if [ "$fail" -ne 0 ]; then
  echo "Kitchen-sink template tests failed"
  exit 1
fi
echo "Kitchen-sink template tests passed"
