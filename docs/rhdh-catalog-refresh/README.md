# Force a Hub catalog refresh (templates from Git)

Software Templates on this lab are **not** in the Helm chart. Hub ingests them from GitHub URL Locations. After you push a template YAML, Hub still serves the **old** `spec` until the catalog processor re-reads that URL.

**Update this file when a refresh fails or a Location URL changes.**

The **Create** wizard has no Refresh button. That control lives on the catalog **entity** About card (`catalog.entity.refresh`), and Template pages often hide it. Use the API below.

## What Hub loads on ROSA rosa-89s85

| Template | Location URL |
|---|---|
| `acme-nodejs-golden-path` | `https://raw.githubusercontent.com/rmallam/RHDH/refs/heads/main/golden-path/demo/template-nodejs-golden-path.yaml` |
| `acme-plugin-kitchen-sink` | `https://raw.githubusercontent.com/rmallam/RHDH/refs/heads/main/golden-path/demo/template-plugin-kitchen-sink.yaml` |

Locations become `location:default/generated-<sha1-of-url>`. Refresh **both** the Location and the Template.

A finished scaffolder **task** keeps the output links from when it ran. Always start a **new** Create after refresh. Hard-refresh `/create` or use a private window so the wizard does not cache the old spec.

## 1. UI (if the button is there)

Open the catalog entity, not Create:

`https://backstage-developer-hub-rhdh.apps.rosa.rosa-89s85.bhg0.p3.openshiftapps.com/catalog/default/template/acme-nodejs-golden-path`

About card → circular refresh. Needs RBAC `catalog.entity.refresh`. Guest on this lab has it; the Create page still will not show the icon.

## 2. Force from the cluster (worked)

Guest token from inside the Hub pod, then `POST /api/catalog/refresh`. Do not print the token.

```bash
oc -n rhdh exec -i deploy/backstage-developer-hub -c backstage-backend -- python3 -u - <<'PY'
import json, urllib.request, urllib.error
base = "http://127.0.0.1:7007"
auth = json.load(urllib.request.urlopen(base + "/api/auth/guest/refresh"))
token = auth["backstageIdentity"]["token"]
headers = {"Authorization": "Bearer " + token, "Content-Type": "application/json"}

def req(method, path, data=None):
    r = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()

code, body = req("GET", "/api/catalog/entities/by-query?filter=kind=location&limit=50")
locs = json.loads(body).get("items") or []
want_urls = (
    "template-nodejs-golden-path.yaml",
    "template-plugin-kitchen-sink.yaml",
)
refs = []
for e in locs:
    target = str((e.get("spec") or {}).get("target") or "")
    name = (e.get("metadata") or {}).get("name")
    if any(u in target for u in want_urls):
        refs.append("location:default/" + name)
        print("LOCATION", name, target)

refs += [
    "template:default/acme-nodejs-golden-path",
    "template:default/acme-plugin-kitchen-sink",
]
for ref in refs:
    code, body = req("POST", "/api/catalog/refresh", json.dumps({"entityRef": ref}).encode())
    print("refresh", ref, code)

code, body = req("GET", "/api/catalog/entities/by-name/template/default/acme-nodejs-golden-path")
spec = json.dumps(json.loads(body).get("spec", {}))
print("has GitHub repository:", "GitHub repository" in spec)
print("has remoteUrl links:", "steps['publish'].output.remoteUrl" in spec)
print("has load-factory:", "/dashboard/#/load-factory?url=" in spec)
print("has old /f factory:", "/f?url=" in spec)
PY
```

Expect `refresh … 200` and `has GitHub repository: True`.

Output **links must use step outputs** (`steps['publish'].output.remoteUrl`), not `parameters.githubOwner` / `parameters.appName`. On this Hub those parameter placeholders render empty, which produced `https://github.com///blob/main/Jenkinsfile`.

Dev Spaces factory from Hub must be the dashboard route (the `/f` path and `host#git-url` both 404 or get eaten by the Hub SPA):

`https://devspaces.apps.rosa.rosa-89s85.bhg0.p3.openshiftapps.com/dashboard/#/load-factory?url=<remoteUrl>&devfilePath=devfile.yaml`

## 3. Prove it

```bash
# After refresh, Create must show these output link titles:
# GitHub repository, catalog-info.yaml, Helm chart, Jenkinsfile,
# Open in catalog, Open in Dev Spaces, Dev Spaces dashboard, OpenShift project
```

If the wizard still shows only “Open in Dev Spaces”, the browser cached the template — private window, then Create again.

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10-08 | No Refresh on Create | Use catalog entity URL or `POST /api/catalog/refresh`. Not a missing RBAC issue on guest. |
| 2026-10-08 | Dev Spaces “We couldn't find that page” | Old template used `/f?url=`. Refresh after pushing the hash factory URL. |
| 2026-10-08 | Create has no Application Name; task `steps: []`; Dev Spaces `url=` missing | RBAC: add `scaffolder.template.parameter.read`, `scaffolder.template.step.read`, `scaffolder.action.execute`. Then hard-refresh `/create` and run Create again (old tasks stay empty). |
| — | Refresh 200 but wizard unchanged | GitHub `raw.githubusercontent.com` CDN delay, or cached Create page. Re-run refresh; private window. |
| — | `Entity template:default/… not found` | That template is not a Location on this Hub (UDI templates are on `RHDH-SM-DevSpaces`, not always registered here). |

## Tests

```bash
docs/rhdh-catalog-refresh/tests/test-docs.sh
```
