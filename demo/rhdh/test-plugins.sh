#!/usr/bin/env bash
# Unit test: demo dynamic-plugins.yaml carries the WNZL plugin set.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
FILE="$DIR/dynamic-plugins.yaml"
fail=0
need() {
  if grep -q "$1" "$FILE"; then
    echo "OK  $1"
  else
    echo "FAIL missing $1"
    fail=1
  fi
}

need "dynamic-plugins.default.yaml"
need "backstage-community-plugin-jenkins"
need "backstage-plugin-catalog-backend-module-ldap-dynamic"
need "backstage-plugin-scaffolder-backend-module-github-dynamic"
need "backstage-plugin-kubernetes"
need "backstage-community-plugin-tekton"
need "backstage-community-plugin-argocd"
need "backstage-community-plugin-jenkins"
need "backstage-community-plugin-sonarqube"
need "rhdh-plugin-snyk"
need "roadiehq-backstage-plugin-jira"
need "backstage-community-plugin-jfrog-artifactory"
need "backstage-community-plugin-vault"
need "backstage-community-plugin-servicenow"
need "backstage-community-plugin-dynatrace"
need "apic-backstage"
need "backstage-plugin-techdocs"

ruby -ryaml -e '
d = YAML.load_file(ARGV[0])
pkgs = (d["plugins"] || []).map { |p| p["plugin"] || p["package"] }
raise "no plugins" if pkgs.empty?
disabled = (d["plugins"] || []).select { |p| p["disabled"] == true }
allowed = disabled.select { |p| p["package"].to_s.match?(/plugin-vault|plugin-snyk|msgraph|keycloak/) }
raise "disabled plugins: #{disabled.map { |p| p["package"] }}" unless disabled == allowed
oci = pkgs.select { |p| p.to_s.start_with?("oci://") }
puts "OK  #{pkgs.size} plugins (#{oci.size} OCI, #{pkgs.size - oci.size} bundled)"
' "$FILE"

if [ "$fail" -ne 0 ]; then
  echo "Plugin list tests failed"
  exit 1
fi
echo "Plugin list tests passed"
