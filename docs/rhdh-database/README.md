# What Developer Hub stores in PostgreSQL

The Hub database schema by schema: what each part holds, which parts can be rebuilt, and where credentials sit. Read it before designing backup and recovery. How the database is installed is in [rhdh-cnpg](../rhdh-cnpg/README.md).

**Update this file when a plugin is added or removed, and after every RHDH upgrade.** Schemas and tables come from the plugins, so they change with plugin versions.

## Layout on sandbox3257 (2026-10-14)

| | |
|---|---|
| Server | CNPG `Cluster/rhdh-pg`, PostgreSQL 18.6, one instance |
| Database | `app`, 30 MB. The only other database is the empty default `postgres` |
| Division | `pluginDivisionMode: schema` — one schema per backend plugin, all owned by role `app` |
| Schemas | 28 |
| Tables | 156 |

Backstage's default is the other mode: one logical **database** per plugin, named `backstage_plugin_<id>`. With `pluginDivisionMode: schema` the same content lands in one database as schemas named after the plugin (`catalog`, `scaffolder`, …), and the `app` role does not need `CREATEDB`. Documentation written for the default mode maps one to one: database `backstage_plugin_catalog` is schema `catalog`.

Either way it is one PostgreSQL cluster with one WAL stream, so backup and recovery are designed once, for the whole thing.

## Schemas that hold data

| Schema | Size | Main tables (rows) | What it is |
|---|---|---|---|
| `catalog` | 7.6 MB | `search` (10,289), `refresh_state` (286), `final_entities` (286), `relations` (558), `locations` (1) | The software catalog. `search` holds about 36 rows per entity and is the largest catalog table |
| `app` | 7.4 MB | `static_assets_cache` (370) | The Hub's own web front end, cached as `bytea` so assets from a previous rollout stay available. Not user data |
| `search` | 864 kB | `documents` (277) | Full-text index. All 277 documents are catalog entries |
| `adoption-insights` | 432 kB | `events` (47), partitioned by month | Usage analytics |
| `auth` | 336 kB | `signing_keys` (2), `user_info` (2), `sessions` (0), `offline_sessions` (0) | Token signing keys and sign-in state |
| `events` | 304 kB | `event_bus_events` (23), `event_bus_subscriptions` (4) | Internal event bus |
| `notifications` | 280 kB | `notification` (0), `broadcast` (0) | Notification inbox |
| `permission` | 216 kB | `casbin_rule` (28), `role-metadata` (2) | RBAC policy as loaded |
| `user-settings` | 160 kB | `user_settings` (4) | Per-user preferences |
| `scaffolder` | 152 kB | `tasks` (0), `task_events` (0) | Template run history. Empty here: no template has been run on this cluster |
| `lightspeed` | 136 kB | `lightspeed_mcp_user_settings` (0) | Lightspeed per-user settings |

## Schemas with bookkeeping only

Seventeen schemas hold no plugin data, 64 to 80 kB each:

`argocd`, `dynamic-plugins-info`, `dynatrace-dql`, `extensions`, `healthcheck`, `jenkins`, `kiali`, `kubernetes`, `licensed-users-info`, `proxy`, `scalprum`, `servicenow`, `signals`, `sonarqube`, `techdocs`, `translations`, `vault`.

Every backend plugin gets a schema whether it stores anything or not. Each contains `backstage_backend_public_keys__keys` (the plugin's service-to-service signing keys) and its Knex migration tables. Plugins that run scheduled work also have `backstage_backend_tasks__tasks`. That is all these seventeen have.

## What can be rebuilt

The useful question for recovery is not how big the database is but how much of it exists nowhere else.

| Data | Rebuilt from | If lost |
|---|---|---|
| `catalog` | Catalog locations in Git and the LDAP provider | Empty catalog for a few minutes, then it refills on the normal refresh cycle |
| `search` | Re-indexing the catalog and TechDocs | Search returns nothing until the collators run |
| `app.static_assets_cache` | The Hub image, at start-up | Nothing visible |
| `auth` | Nothing to rebuild | Users sign in again |
| `permission` | The RBAC CSV file and `permission.rbac` in app-config | Reloaded at start-up, **provided no policy was created in the UI**. Check `role-metadata.source` (below) |
| The seventeen bookkeeping schemas | Created at start-up | Nothing visible |
| `scaffolder` | **Nothing** | The record of who created what, from which template, with which parameters, is gone |
| `user-settings` | **Nothing** | Users lose their preferences |
| `adoption-insights`, `notifications`, `events` | **Nothing** | Usage history and unread notifications are gone |

On this cluster `role-metadata.source` shows one role from `csv-file` and one from `configuration`, and none from `rest`. So all policy here comes from git, and the `permission` schema is a loaded copy. A role created in the RBAC UI is stored with source `rest` and exists only in the database.

```sql
select source, count(*) from permission."role-metadata" group by 1;
```

Scaffolder history is therefore the one dataset that both matters and cannot be regenerated. It is audit data, not transactional data. It also only grows: every template run adds a row to `tasks` and many to `task_events`, so decide a retention period before the table is large.

## Credentials in the database

The database is a secret store whether or not it is treated as one.

| Column | Holds |
|---|---|
| `scaffolder.tasks.secrets` | Secrets passed to a template run, for example the user's SCM token |
| `auth.offline_sessions.token_hash` | Refresh-token hashes |
| `auth.oidc_clients.client_secret` | Client secrets of registered OIDC clients |
| `auth.signing_keys.key` | The keys the Hub signs its own tokens with |
| `lightspeed.lightspeed_mcp_user_settings.token` | Per-user tokens for MCP servers |

Base backups, the WAL archive and any dump need the same encryption and access control as the secret store itself. A `pg_dump --schema-only` contains none of this and is safe to share; a full dump is not.

## TechDocs is not here

The `techdocs` schema is one of the seventeen bookkeeping-only schemas. Generated documentation is never stored in PostgreSQL: the TechDocs publisher writes to local storage or to object storage, and there is no database publisher. The only TechDocs content that reaches the database is page text in the `search` index. See [techdocs](../rhdh-plugins/techdocs.md).

## Connections

One Hub replica held 51 connections to `app` against `max_connections` 200. Multiply by the replica count before choosing `max_connections`: three replicas at this plugin set would not fit under the PostgreSQL default of 100.

```sql
select usename, count(*) from pg_stat_activity where datname = 'app' group by 1;
show max_connections;
```

## Not a sizing reference

Of the 286 catalog entities, 264 are the Hub's own Extensions entries (177 `package`, 87 `plugin`). Two are components, and no template has run. The sizes above show which tables dominate, not how large a real installation gets.

## Look for yourself

All read-only.

```bash
PSQL="oc -n rhdh exec rhdh-pg-1 -c postgres -- psql -U postgres -d app -X"

# Schemas with table count and size
$PSQL -c "select n.nspname, count(c.oid) filter (where c.relkind='r') as tables,
                 pg_size_pretty(coalesce(sum(pg_total_relation_size(c.oid)) filter (where c.relkind='r'),0)) as size
          from pg_namespace n left join pg_class c on c.relnamespace=n.oid
          where n.nspname not like 'pg_%' and n.nspname<>'information_schema'
          group by 1 order by coalesce(sum(pg_total_relation_size(c.oid)) filter (where c.relkind='r'),0) desc;"

# Tables of one schema
$PSQL -c '\dt catalog.*'

# Structure only: no rows, no credentials
oc -n rhdh exec rhdh-pg-1 -c postgres -- pg_dump -U postgres -d app --schema-only --no-owner --no-privileges > rhdh-schema.sql
```

## Production deltas

| Lab | Production |
|---|---|
| No backup at all | Base backups plus continuous WAL archiving, encrypted, in a bucket with its own access policy |
| One instance | Replicas; a standby cluster in the second site if there is one |
| Scaffolder history kept forever | A stated retention period |
| RBAC policy only in git | Keep it that way, or accept that the `permission` schema becomes data to protect |
| `max_connections` 200 for one replica | Sized for the real replica count |
| Analytics, Lightspeed and notification schemas present | Present only if those plugins are wanted |

## Tests

```bash
docs/rhdh-database/tests/test-docs.sh
```

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10-14 | `\dt` lists only six tables, `static_assets_cache` among them | Connected as role `app`, psql's search path looks in the schema named after the role, which is the `app` plugin's schema. Use `\dn` for all schemas and `\dt <schema>.*` for another schema's tables |
| — | `relation "role-metadata" does not exist` | Schema and table names with a hyphen need double quotes: `permission."role-metadata"`, `"user-settings".user_settings` |
