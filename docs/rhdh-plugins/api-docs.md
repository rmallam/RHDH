# API Docs

**Status:** disabled (demo)

Renders OpenAPI on API entities.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.apiDocs.enabled: true` |
| Package | in-tree `backstage-plugin-api-docs` |
| Catalog | API entity with `spec.definition` (`$text: ./openapi.yaml`) |

`values-demo.yaml` sets `enabled: false`. Production values leave it on.

## Known issues

None — off on this lab by choice.
