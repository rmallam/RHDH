#!/usr/bin/env bash
# Copy the community OCI plugin list with skopeo (podman auth).
# Prefer Red Hat mirror-plugins.sh for the catalog index + this list together.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="${PLUGIN_LIST:-$ROOT/plugins-oci.txt}"
INTERNAL_REGISTRY="${INTERNAL_REGISTRY:-registry.internal.example.com}"
# GHCR path is 3-level; Harbor usually keeps it. OpenShift internal registry
# cannot — set FLATTEN=1 to keep only the last two path segments.
FLATTEN="${FLATTEN:-0}"

usage() {
  echo "Usage: $0 export <dir> | import <dir> | push-online"
  echo "  export <dir>     Pull OCI artifacts to dir (connected host)"
  echo "  import <dir>     Push dir to INTERNAL_REGISTRY (disconnected host)"
  echo "  push-online      skopeo copy source -> INTERNAL_REGISTRY (bastion sees both)"
  echo
  echo "Env: INTERNAL_REGISTRY  FLATTEN=0|1  PLUGIN_LIST"
  exit 1
}

refs() {
  grep -E '^oci://' "$LIST" | sed 's|^oci://||'
}

dest_path() {
  local rest="$1" # registry/path:tag
  local path="${rest#*/}"
  if [[ "$FLATTEN" == "1" ]]; then
    local last two
    last="$(echo "$path" | awk -F/ '{print $(NF-1)"/"$NF}')"
    echo "$last"
  else
    echo "$path"
  fi
}

cmd="${1:-}"
dir="${2:-}"

case "$cmd" in
  export)
    [[ -n "$dir" ]] || usage
    mkdir -p "$dir"
    while read -r rest; do
      [[ -z "$rest" ]] && continue
      safe="$(echo "$rest" | tr '/:' '__')"
      echo "SAVE docker://$rest -> dir:$dir/$safe"
      skopeo copy --all "docker://$rest" "dir:$dir/$safe"
    done < <(refs)
    echo "$INTERNAL_REGISTRY" >"$dir/INTERNAL_REGISTRY.txt"
    ;;
  import)
    [[ -n "$dir" ]] || usage
    while read -r rest; do
      [[ -z "$rest" ]] && continue
      safe="$(echo "$rest" | tr '/:' '__')"
      dest="$INTERNAL_REGISTRY/$(dest_path "$rest")"
      echo "LOAD dir:$dir/$safe -> docker://$dest"
      skopeo copy --all "dir:$dir/$safe" "docker://$dest"
    done < <(refs)
    ;;
  push-online)
    while read -r rest; do
      [[ -z "$rest" ]] && continue
      dest="$INTERNAL_REGISTRY/$(dest_path "$rest")"
      echo "COPY docker://$rest -> docker://$dest"
      skopeo copy --all "docker://$rest" "docker://$dest"
    done < <(refs)
    ;;
  *)
    usage
    ;;
esac
