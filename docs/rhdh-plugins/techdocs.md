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

## Where the generated docs live

`publisher: local` writes the generated site to a `static` directory inside the Hub pod. It is not in PostgreSQL: the `techdocs` schema holds no content (see [rhdh-database](../rhdh-database/README.md)), and TechDocs has no database publisher. The publisher types are `local`, `awsS3`, `googleGcs`, `azureBlobStorage` and `openStackSwift`: a pod directory or an object store, nothing else.

On this lab that is fine: one replica, and a rebuild on first view after a restart is quick. It does not scale past one replica:

| With `local` | Effect |
|---|---|
| More than one Hub replica | Each pod builds and keeps its own copy; a page can be present on one replica and missing on another |
| Pod restart or rollout | The directory is gone and every site is rebuilt on first view |
| `builder: local` | The Hub pod runs `mkdocs` itself, on request |

Red Hat's guide says the default local setup is not intended for production and names OpenShift Data Foundation as the recommended storage for air-gapped environments. A production install uses `publisher.type: awsS3` against an S3-compatible bucket (ODF works), and usually `builder: external` with CI running `techdocs-cli` so the Hub only reads.

Rough size, as an estimate and not a measurement: a few MB per documented component before content, 10 to 20 MB for a well-illustrated one. To replace the estimate, run `techdocs-cli generate` on a real repository and measure the output directory.

## Known issues

| When | Error | Fix |
|---|---|---|
| — | “Documentation not found” | Add `mkdocs.yml` and `docs/index.md` next to `catalog-info.yaml` |
