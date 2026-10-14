#!/usr/bin/env bash
# Unit: the database page keeps the layout facts, the rebuild table,
# the credential columns and the read-only commands.
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
need "Update this file when a plugin is added or removed"
need "pluginDivisionMode: schema"
need "backstage_plugin_<id>"
need "static_assets_cache"
need "## Schemas with bookkeeping only"
need "## What can be rebuilt"
need "role-metadata"
need "## Credentials in the database"
need "scaffolder.tasks.secrets"
need "## TechDocs is not here"
need "max_connections"
need "pg_dump -U postgres -d app --schema-only"
need "## Production deltas"
need "## Known issues"
if [ "$fail" -ne 0 ]; then
  echo "Database docs tests failed"
  exit 1
fi
echo "Database docs tests passed"
