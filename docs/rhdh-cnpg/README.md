# RHDH backing store: CloudNativePG

Reuse this on the next cluster. Hub must **not** use the operator-bundled `backstage-psql-*` StatefulSet. The database is a CloudNativePG `Cluster` in the same namespace as Hub (`rhdh`).

**Update this file when a cutover fails or a fix lands.**

## What runs on ROSA rosa-89s85 (worked)

| Piece | Value |
|---|---|
| Operator package | `cloudnative-pg` from **Certified Operators** (EnterpriseDB) |
| Channel / CSV | `stable-v1` / `cloudnative-pg.v1.30.1` |
| Operator namespace | `cnpg-system` (AllNamespaces OperatorGroup) |
| Cluster CR | `rhdh-pg` in `rhdh` |
| Instances / storage | `1` / `10Gi` (default StorageClass `gp3-csi`) |
| Service Hub uses | `rhdh-pg-rw.rhdh.svc:5432` |
| Database / user | `app` / `app` (CNPG default owner) |
| Credential Secret | `rhdh-pg-app` (created by CNPG, not Vault) |
| Hub CR | `spec.database.enableLocalDb: false` |
| App-config | `backend.database.client: pg`, `pluginDivisionMode: schema` |
| Helm release | `rhdh` revision 14+ |

`pluginDivisionMode: schema` keeps every plugin in **one** database as schemas. The `app` role does not need `CREATEDB`.

Switching off the local DB **wipes Hub state** (catalog, sessions, scaffolder history). LDAP and catalog locations re-import. There is no dump/restore in this lab path.

## What runs on sandbox3257 (2026-10-15)

Same pattern, two differences from the table above: the `Cluster` CR now comes from `rmallam/rhdh-platform-gitops` (`charts/cnpg`, Argo app `cnpg`), and the Hub chart there has `database.cnpg.enabled: false` so it only reads the Secret.

| Piece | Value |
|---|---|
| Operator | `cloudnative-pg.v1.30.1`, channel `stable-v1`, `cnpg-system` |
| Cluster CR | `rhdh-pg` in `rhdh`, 3 instances, 10Gi each on `gp3-csi`, `max_connections` 200 |
| DR test cluster | `rhdh-pg-dr` in `rhdh-dr`, 3 instances, 10Gi each. Same chart with `values-dr.yaml` (Argo app `cnpg-dr`). Not used by the Hub and not replicating from `rhdh-pg` |
| Postgres image | `ghcr.io/cloudnative-pg/postgresql:18.6-system-trixie` — **PostgreSQL 18.6** |
| Why 18 | `cluster.imageName` is empty, so the operator filled in its own default. Nobody chose 18 |
| Plugin schemas | 28 plugin schemas in database `app` (`pluginDivisionMode: schema`). Contents: [rhdh-database](../rhdh-database/README.md) |
| Connections | 51 from one Hub replica, against `max_connections` 200 |
| Backup | None. No `ScheduledBackup`, no object store |

**Pin `imageName`.** With it empty, the Postgres major version is whatever the installed operator release defaults to, and an operator upgrade changes that default for every cluster created afterwards. Check the major version against the RHDH supported-configurations page for the release in use before pinning; do not assume the operator default is one RHDH supports.

```bash
oc -n rhdh get cluster.postgresql.cnpg.io rhdh-pg -o jsonpath='{.status.image}{"\n"}'
oc -n rhdh exec rhdh-pg-1 -c postgres -- psql -U postgres -tAc 'select version();'
```

Moving **down** a major version (18 to 17) cannot be done in place: `pg_upgrade` only goes up. Either create a new `Cluster` on the target version and import a logical dump, or, on a lab, delete and recreate the `Cluster` and let LDAP and the catalog locations re-import (this wipes Hub state, as the cutover above did). Moving **up** is an offline operation in recent CNPG releases; check the operator's major-upgrade documentation and plan a Hub outage.

## File map

| Path | Owns |
|---|---|
| `components/cnpg/base/` | Namespace, OperatorGroup, OLM Subscription |
| `argocd/apps/cnpg.yaml` | Argo Application → that kustomize |
| `charts/developer-hub/templates/cnpg-cluster.yaml` | `Cluster` CR (`database.cnpg.enabled`) |
| `charts/developer-hub/templates/backstage.yaml` | `enableLocalDb` + `POSTGRES_*` env from `rhdh-pg-app` |
| `charts/developer-hub/templates/configmap-app-config.yaml` | `backend.database` when `database.external.enabled` |
| `charts/developer-hub/values.yaml` | Safe defaults: local DB on, CNPG off |
| `charts/developer-hub/values-demo.yaml` | Lab: local DB off, CNPG on, 1 instance |

Operator stays **out of the Helm chart** (same rule as Jenkins/Vault installs). The Cluster is in the chart because it is Hub’s database.

## Values to copy

Customer / next DC — start from `values.yaml` and overlay:

```yaml
instance:
  database:
    enableLocalDb: false          # required or the operator keeps backstage-psql-*
database:
  cnpg:
    enabled: true
    name: rhdh-pg                 # Secret becomes <name>-app
    instances: 2                  # lab used 1; bank DC should be 2–3
    storage: 20Gi
    storageClass: ""              # empty = cluster default
    imageName: ""                 # empty = operator default Postgres image
    maxConnections: "200"
  external:
    enabled: true
    secretName: rhdh-pg-app
    keys:                         # CNPG 1.30 app Secret field names
      host: host
      port: port
      user: username              # also published as `user`
      password: password
      database: dbname
    ssl:
      rejectUnauthorized: false   # lab. Prod: mount <name>-ca and set true
```

Lab overlay (`values-demo.yaml`) is exactly: `enableLocalDb: false`, `cnpg.enabled: true`, `instances: 1`, `storage: 10Gi`, `external.enabled: true`.

## Secret mapping (do not put passwords in git)

CNPG writes `rhdh-pg-app` with keys `host`, `port`, `username`/`user`, `password`, `dbname`, plus `uri`. The Backstage deployment patch maps those to:

| Env in Hub | Secret key |
|---|---|
| `POSTGRES_HOST` | `host` (value `rhdh-pg-rw`) |
| `POSTGRES_PORT` | `port` (`5432`) |
| `POSTGRES_USER` | `username` |
| `POSTGRES_PASSWORD` | `password` |
| `POSTGRES_DB` | `dbname` |

Those env vars are **not** in Vault / `rhdh-secrets`. If the Secret is missing, the Hub pod stays Pending (`secretKeyRef`).

## Install on a new cluster (order matters)

```bash
# 1) Operator + CRD
oc apply -k components/cnpg/base
oc -n cnpg-system wait csv/cloudnative-pg.v1.30.1 --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s
oc get crd clusters.postgresql.cnpg.io

# 2) Cluster + Hub in one Helm upgrade (demo overlay is the end state)
helm upgrade --install rhdh charts/developer-hub -n rhdh \
  --take-ownership --force-conflicts \
  -f charts/developer-hub/values.yaml \
  -f charts/developer-hub/values-demo.yaml

# 3) Wait for Postgres, then Hub
oc -n rhdh wait cluster.postgresql.cnpg.io/rhdh-pg --for=jsonpath='{.status.readyInstances}'=1 --timeout=300s
oc -n rhdh get secret rhdh-pg-app
oc -n rhdh rollout status deploy/backstage-developer-hub --timeout=600s

# 4) Remove leftover bundled Postgres if the operator left it
oc -n rhdh delete sts backstage-psql-developer-hub --ignore-not-found
oc -n rhdh delete pvc -l app.kubernetes.io/name=backstage-psql --ignore-not-found
```

Argo: `oc apply -f argocd/apps/cnpg.yaml` (source `https://github.com/rmallam/RHDH`, path `components/cnpg/base`). Hub Argo app already points at the Helm chart.

If you apply Helm **before** the CRD exists, the `Cluster` object is skipped until the next sync (`SkipDryRunOnMissingResource`). Hub will Pending until `rhdh-pg-app` exists — do not flip `enableLocalDb` back to true.

## Verify

```bash
oc -n cnpg-system get csv,pods
oc -n rhdh get cluster.postgresql.cnpg.io rhdh-pg
oc -n rhdh get pods -l cnpg.io/cluster=rhdh-pg
oc -n rhdh exec deploy/backstage-developer-hub -c backstage-backend -- \
  printenv POSTGRES_HOST POSTGRES_PORT POSTGRES_USER POSTGRES_DB
# expect: rhdh-pg-rw / 5432 / app / app
oc -n rhdh get sts backstage-psql-developer-hub   # NotFound
```

Catalog empty for a few minutes after cutover is normal (LDAP + locations). Sign out and back in.

## Next cluster / production deltas

| Lab | Next DC |
|---|---|
| 1 instance | `database.cnpg.instances: 2` or `3` |
| `ssl.rejectUnauthorized: false` | mount Secret `rhdh-pg-ca` (`ca.crt`) via `extraFiles.secrets` and set `rejectUnauthorized: true` |
| No object-store backup | add CNPG `ScheduledBackup` + Barman plugin when the bank has a bucket |
| `imageName: ""` (operator default, PostgreSQL 18.6 today) | pin the image and major version the customer has approved |
| `Cluster` in the Hub namespace | a separate database namespace if the platform requires one; the Hub then reads `rhdh-pg-app` across namespaces, so copy or sync the Secret |
| Operator from OLM (`certified-operators`) | some platforms install certified operators from the upstream Helm chart instead; the CRDs and the `Cluster` CR are the same, the install and upgrade path are not |
| Helm applied by hand | same values via Argo `developer-hub-demo` / `developer-hub` |

Do **not** install a second Subscription in `rhdh`. Operator stays in `cnpg-system`.

## Tests

```bash
components/cnpg/tests/test-manifests.sh
charts/developer-hub/tests/test-chart.sh
docs/rhdh-cnpg/tests/test-docs.sh
```

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10-08 | Hub would use bundled Postgres | `enableLocalDb: false` + CNPG Cluster + env from `rhdh-pg-app` |
| — | Pending missing `rhdh-pg-app` | Wait for Cluster Ready; do not re-enable local DB |
| — | `password authentication failed` / SSL | Check key `username` (not only `user`); lab SSL `rejectUnauthorized: false` |
| — | Empty catalog after cutover | Expected; LDAP + locations re-sync |
| — | `backstage-psql-*` still Running | Operator may leave the old STS; delete STS + PVC after Hub is healthy on CNPG |
| 2026-10-14 | `Namespace/rhdh` flips between two label sets; `developer-hub` Application OutOfSync | `charts/cnpg` and `charts/developer-hub` (in `rhdh-platform-gitops`) both render the namespace. Set `createNamespace: false` in `charts/cnpg/values.yaml`. Side effect and detail: [service-mesh-ambient](../service-mesh-ambient/README.md#known-issues) |
