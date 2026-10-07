# TechDocs

**Status:** working

Renders `mkdocs.yml` from the repo on the Component docs tab.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.techdocs.enabled: true` |
| Packages | in-tree techdocs frontend + backend |
| App-config | `techdocs.builder: local`, `publisher: local` |
| Catalog | `backstage.io/techdocs-ref: dir:.` |
| Repo | `mkdocs.yml` + `docs/index.md` at the ref |

No extra secrets. Kitchen-sink annotation is present; that entity has no mkdocs tree (empty docs). The golden-path kitchen-sink template ships `mkdocs.yml`.

## Known issues

| When | Error | Fix |
|---|---|---|
| — | “Documentation not found” | Add `mkdocs.yml` and `docs/index.md` next to `catalog-info.yaml` |
