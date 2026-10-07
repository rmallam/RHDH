#!/usr/bin/env bash
# Export vendor Snyk (backstage-plugin-snyk) as an RHDH dynamic OCI image
# and push to YOUR GHCR — not ghcr.io/redhat-developer (we cannot write there).
#
# Prerequisites:
#   Node 20+, npm 7+, yarn (plugin uses yarn 4)
#   podman machine running  (podman, not docker)
#   gh auth login   OR   podman login ghcr.io
#
# Usage:
#   ./export-snyk-plugin.sh              # clone + export + package locally
#   ./export-snyk-plugin.sh push         # also podman push
#
# Then in dynamic-plugins.yaml:
#   package: oci://ghcr.io/<gh-user>/rhdh-plugin-snyk:<TAG>!backstage-plugin-snyk
#   disabled: false
set -euo pipefail

GHCR_OWNER="${GHCR_OWNER:-rmallam}"
# Pin a published git tag; main is 0.0.0-development.
SNYK_REF="${SNYK_REF:-v2.5.10}"
SNYK_REPO="${SNYK_REPO:-https://github.com/snyk-tech-services/backstage-plugin-snyk.git}"
WORK="${WORK:-/tmp/rhdh-snyk-export}"
TAG="${TAG:-bs_1.49.4__2.5.10}"
CLI="${CLI:-@red-hat-developer-hub/cli@1.10.8}"
IMAGE="ghcr.io/${GHCR_OWNER}/rhdh-plugin-snyk:${TAG}"
DO_PUSH="${1:-}"

need() { command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 1; }; }
need git
need npx
need podman

if ! podman info >/dev/null 2>&1; then
  echo "podman is not running. Start it: podman machine start" >&2
  exit 1
fi

rm -rf "${WORK}"
mkdir -p "${WORK}"
git clone --depth 1 --branch "${SNYK_REF}" "${SNYK_REPO}" "${WORK}/src"
cd "${WORK}/src"

# Vendor plugin uses yarn 4 + backstage:^ protocol. CLI webpack needs node_modules.
corepack enable
corepack prepare yarn@4.10.3 --activate
yarn install --immutable

# CLI webpack needs a string entry; prefer TypeScript source, not compiled dist.
python3 - <<'PY'
import json
from pathlib import Path
p = Path("package.json")
d = json.loads(p.read_text())
src = Path("src/index.ts")
entry = "./src/index.ts" if src.exists() else "./dist/src/index.js"
d["exports"] = {".": entry, "./package.json": "./package.json"}
if Path("src/alpha/index.ts").exists():
    d["exports"]["./alpha"] = "./src/alpha/index.ts"
d["main"] = entry
d["scalprum"] = {
    "name": "backstage-plugin-snyk",
    "exposedModules": {"PluginRoot": entry},
}
p.write_text(json.dumps(d, indent=2) + "\n")
print(f"package.json entry -> {entry}")
PY

# Frontend plugin; RHDH 1.10 shares @backstage/* from the hub image.
npx --yes "${CLI}" plugin export --clean
test -d dist-dynamic

npx --yes "${CLI}" plugin package \
  --container-tool podman \
  --tag "${IMAGE}"

echo
echo "Built ${IMAGE}"
echo "RHDH package line:"
echo "  oci://${IMAGE}!backstage-plugin-snyk"

if [[ "${DO_PUSH}" == "push" ]]; then
  if ! podman login --get-login ghcr.io >/dev/null 2>&1; then
    echo "Not logged in to ghcr.io. Run: echo \$GHCR_PAT | podman login ghcr.io -u ${GHCR_OWNER} --password-stdin" >&2
    exit 1
  fi
  podman push "${IMAGE}"
  echo "Pushed ${IMAGE}"
else
  echo "Local image only. Re-run with: $0 push"
fi
