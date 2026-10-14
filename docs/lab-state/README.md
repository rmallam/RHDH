# Lab state: what is running, and what is not

One page for the current cluster. The other runbooks say how each piece is built; this one says what is deployed right now, in what version, and which parts of the repos are **not** on the cluster.

**Update this file after every rebuild or operator upgrade.** The older runbooks still name the first cluster (`rosa-89s85`). Treat a cluster name in any doc as "where this was last proven", not as the current lab.

## Cluster

| | |
|---|---|
| Cluster | RHDP sandbox, base domain `ocp.dkccw.sandbox3257.opentlc.com` |
| Apps domain | `apps.ocp.dkccw.sandbox3257.opentlc.com` |
| Dev Spaces shard domain | `devspaces.ocp.dkccw.sandbox3257.opentlc.com` |
| OpenShift | 4.20.40 (Kubernetes v1.33.13) |
| Nodes | 6 — 3 × `m5a.2xlarge`, 3 × `m6a.4xlarge` |
| Default StorageClass | `gp3-csi` (RWO only; no RWX class) |
| Recorded | 2026-10-14 |

The previous cluster, `rosa-89s85.bhg0.p3.openshiftapps.com`, is gone. `charts/developer-hub/values-demo.yaml` in **this** repo still points at it. The live Hub is deployed from `rmallam/rhdh-platform-gitops`, where `values-deploy.yaml` carries the current domain.

## Operators

All Subscriptions use `installPlanApproval: Automatic`, so every operator sits at the head of its channel and moves on its own.

| Operator | Namespace | Channel | Installed CSV |
|---|---|---|---|
| Red Hat Developer Hub | `openshift-operators` | `fast-1.10` | `rhdh-operator.v1.10.5` |
| OpenShift Service Mesh 3 | `openshift-operators` | `stable` | `servicemeshoperator3.v3.4.3` |
| Kiali | `openshift-operators` | `stable` | `kiali-operator.v2.27.5` |
| OpenShift Dev Spaces | `openshift-operators` | `stable` | `devspacesoperator.v3.30.2` |
| DevWorkspace | `openshift-operators` | `fast` | `devworkspace-operator.v0.43.0` |
| OpenShift GitOps | `openshift-operators` | `latest` | `openshift-gitops-operator.v1.22.1` |
| CloudNativePG | `cnpg-system` | `stable-v1` | `cloudnative-pg.v1.30.1` |
| Red Hat build of Keycloak | `keycloak` | `stable-v26.4` | `rhbk-operator.v26.4.16-opr.1` |
| cert-manager | `cert-manager-operator` | `stable-v1` | `cert-manager-operator.v1.20.1` |

External Secrets is **not** an OLM operator here. It is the upstream Helm chart from `charts.external-secrets.io`, installed by the Argo app `external-secrets`.

```bash
oc get subscriptions.operators.coreos.com -A \
  -o custom-columns='NS:.metadata.namespace,PKG:.spec.name,CHANNEL:.spec.channel,CSV:.status.installedCSV'
```

## Workloads

| What | Where | Version / shape |
|---|---|---|
| `Backstage/developer-hub` | `rhdh` | `rhdh.redhat.com/v1alpha5`, 1 replica, `enableLocalDb: false` |
| CNPG `Cluster/rhdh-pg` | `rhdh` | 1 instance, 10Gi, **PostgreSQL 18.6** (`postgresql:18.6-system-trixie`), `max_connections` 200, no backup |
| `Istio/default` | `istio-system` | `profile: ambient`, v1.30.5, `InPlace` |
| `IstioCNI/default` | `istio-cni` | ambient, DaemonSet 6/6 |
| `ZTunnel/default` | `ztunnel` | v1.30.5, DaemonSet 6/6 |
| `Kiali/kiali` | `istio-system` | `auth.strategy: anonymous` |
| `CheCluster/devspaces` | `openshift-devspaces` | 3.30.2, phase Active |
| `IngressController/devspaces` | `openshift-ingress-operator` | 1 replica, shard label `ingress.openshift.io/shard=devspaces` |
| `Keycloak/keycloak` | `keycloak` | Route `sso.apps…`; not used by the Hub (Keycloak catalog plugin is disabled) |
| OpenLDAP | `ldap` | `osixia/openldap:1.5.0`, `emptyDir`, 3 users / 3 groups |
| Jenkins, Vault | `jenkins`, `vault` | Test installs from `tools/` |

Hub plugin versions and load status are in [rhdh-plugins](../rhdh-plugins/README.md#installed-on-sandbox3257). What the database holds, schema by schema, is in [rhdh-database](../rhdh-database/README.md).

## Argo CD applications

One Argo CD instance (`openshift-gitops`). Eleven Applications.

| Application | Repo | Path | State (2026-10-14) |
|---|---|---|---|
| `idp-platform` | `rhdh-platform-gitops` | `argocd/apps` | Synced — app-of-apps for the four below |
| `cnpg` | `rhdh-platform-gitops` | `charts/cnpg` | Synced |
| `service-mesh` | `rhdh-platform-gitops` | `charts/service-mesh` | Synced |
| `devspaces` | `rhdh-platform-gitops` | `charts/devspaces` | Synced |
| `developer-hub` | `rhdh-platform-gitops` | `charts/developer-hub` | **OutOfSync** — see below |
| `external-secrets` | `charts.external-secrets.io` | Helm chart | Synced |
| `vault-secret-store` | `RHDH` | `tools/eso` | Synced |
| `vault` | `RHDH` | `tools/vault/base` | Synced |
| `jenkins` | `RHDH` | `tools/jenkins/base` | Synced |
| `ldap` | `RHDH` | `tools/ldap` | Synced |
| `ingress-shard` | `RHDH` | `tools/ingress-shard` | Synced |

`developer-hub` shows OutOfSync on **one object only: the `rhdh` Namespace**. The application is at the repo HEAD and every other resource is Synced, so the Hub configuration in git is what is running.

The Namespace is rendered by both the `cnpg` chart and the `developer-hub` chart. Both Applications use server-side apply under the same field manager (`argocd-controller`), so whichever syncs last owns the labels and the other's are dropped. Today `cnpg` wins: the namespace carries `app.kubernetes.io/name=cnpg` and has **lost `istio.io/dataplane-mode: ambient`**, which the Hub chart sets through `mesh.ambient: true`. That is why nothing is enrolled in the mesh. Fix and consequences: [service-mesh-ambient](../service-mesh-ambient/README.md#known-issues).

## In the repos but not on the cluster

Do not assume a manifest in git is deployed.

| In git | On the cluster | Effect |
|---|---|---|
| `argocd/apps/sonarqube.yaml`, `tools/sonarqube` | Not applied; no `sonarqube` namespace | Hub is configured for `http://sonarqube.sonarqube.svc:9000` and gets nothing back |
| `argocd/apps/saas-stubs.yaml`, `tools/saas-stubs` | Not applied; no `saas-stubs` namespace | Jira, ServiceNow, Dynatrace, APIC and Artifactory cards have no backend. The plugin status table was recorded when the stubs were running |
| `docs/rhdh-disconnected-plugins/plugins-oci.txt` (target pins) | Older pins still loaded | See [rhdh-plugins](../rhdh-plugins/README.md#installed-on-sandbox3257) |
| Catalog locations on `rmallam/RHDH-SM-DevSpaces` | Repo returns 404 without credentials | The three Dev Spaces templates (`template-node-udi-devspaces`, `template-start-feature-devspaces`, `template-open-devspaces-namespace`) do not load for anyone outside that repo |
| Snyk plugin | Not loaded | The self-exported image is private; commit `abc1bbd` skips it |

## Not built yet

| Area | State |
|---|---|
| Mesh workloads | None enrolled. `Istio` reports `IN USE 0`. See [service-mesh-ambient](../service-mesh-ambient/README.md) |
| Mesh policy | No `PeerAuthentication`, `AuthorizationPolicy`, waypoint or `Gateway` |
| User workload monitoring | Off. The mesh `ServiceMonitor` and `PodMonitor` are not scraped |
| Tekton | No Pipelines operator, so the Tekton plugin has nothing to show |
| Second Argo CD instance | Only the default instance exists |
| Database backup | No `ScheduledBackup`, no object store |

## Lab-only settings

Everything here exists to make a throwaway cluster convenient. None of it belongs in a customer install.

| Setting | Where | Why it must change |
|---|---|---|
| `auth.environment: development` | Hub `values-demo.yaml` | Production provider block is a copy; use `production` |
| Guest sign-in, with `user:default/guest` as RBAC admin | Hub `values-demo.yaml` | Anyone who can reach the Route is an administrator |
| Second sign-in resolver with `dangerouslyAllowSignInWithoutUserInCatalog: true` | Hub `values-demo.yaml` | Lets a user in with no catalog entity, which bypasses LDAP provisioning. Keep one resolver |
| `backend.database.connection.ssl.rejectUnauthorized: false` | Hub `values-demo.yaml` | Mount `rhdh-pg-ca` and set `true` |
| Kiali `auth.strategy: anonymous`, `cluster_wide_access: true` | `charts/service-mesh` | Use `openshift` |
| Argo CD controller bound to `cluster-admin` | `argocd/gitops-controller-admin.yaml` | Scope to the namespaces and CRDs it manages |
| OpenLDAP on `emptyDir` with passwords in `bootstrap.ldif` | `tools/ldap` | Stand-in for a corporate directory |
| Vault in `-dev` mode | `tools/vault` | In-memory, root token |
| Automatic install-plan approval, `openshift-operators` | All Subscriptions | Pin a starting CSV, Manual approval, operator-specific namespaces where the platform requires them |
| CNPG 1 instance / 10Gi / no backup | `charts/cnpg` | See [rhdh-cnpg](../rhdh-cnpg/README.md) |
| `defaultEditor: …/che-code/latest`, `istio.version: ""` | Dev Spaces and mesh charts | Pin both for a freeze |
| Segment analytics provider, Lightspeed | Default RHDH 1.10 plugin profile | Loaded unless disabled; decide per customer |

## Rebuild order on a fresh cluster

Both repos are needed. The split is: operators and test tools from `RHDH`, custom resources from `rhdh-platform-gitops`.

This order is read from the scripts. It has **not** been replayed end to end on an empty cluster, so treat the first rebuild as a test of this page.

```bash
# 1. OpenShift GitOps (OperatorHub), then let its controller create cluster-scoped CRs
oc apply -f rhdh-platform-gitops/argocd/gitops-controller-admin.yaml

# 2. Operators: RHDH, Service Mesh 3, Kiali, Dev Spaces from OperatorHub; CNPG from this repo
oc apply -k RHDH/components/cnpg/base

# 3. LDAP first, because its admin password goes into the bootstrap Secret.
#    deploy.sh creates ldap/openldap-admin with a random password, then the directory.
RHDH/tools/ldap/deploy.sh

# 4. Namespace and bootstrap Secret. Both secret scripts READ rhdh/rhdh-secrets,
#    so it must exist before either runs. Fill a copy of the example; do not commit it.
#    LDAP_BIND_PASSWORD is the value in ldap/openldap-admin. No script copies it.
oc create namespace rhdh
oc -n rhdh apply -f my-rhdh-secrets.yaml   # from rhdh-platform-gitops/examples/rhdh-secrets.example.yaml

# 5. Test tools. deploy.sh applies Jenkins, SonarQube, Vault and saas-stubs,
#    waits for them, then merges their tokens into rhdh/rhdh-secrets.
RHDH/tools/install/deploy.sh

# 6. External Secrets and the secret store, then copy the Secret into Vault.
#    seed-vault.py needs the external-secrets namespace and writes vault-eso-token there.
oc apply -f RHDH/argocd/apps/external-secrets.yaml   # also defines the vault-secret-store Application
python3 RHDH/scripts/seed-vault.py

# 7. The Dev Spaces shard, and hand LDAP to Argo CD
oc apply -f RHDH/argocd/apps/ingress-shard.yaml -f RHDH/argocd/apps/ldap.yaml

# 8. Set the cluster domain, then the custom resources
#    rhdh-platform-gitops/charts/developer-hub/values-deploy.yaml  app.clusterBaseDomain, devspacesBaseUrl
#    rhdh-platform-gitops/charts/devspaces/values-deploy.yaml      networking.domain
#    RHDH/tools/ingress-shard/ingresscontroller.yaml               spec.domain
oc apply -f rhdh-platform-gitops/argocd/app-of-apps.yaml
```

Three things about this order:

- **Step 5 needs all four tools.** `wire-rhdh-secrets.py` reads the SonarQube and saas-stubs Routes and stops if either is missing, so `deploy.sh` cannot be used to install only Jenkins and Vault.
- **A rebuild therefore ends with SonarQube and saas-stubs running**, which the current cluster does not have (see [In the repos but not on the cluster](#in-the-repos-but-not-on-the-cluster)). Either they were removed here after bootstrap or this cluster was wired another way. Decide which state is wanted: keep them and the plugin status table applies again, or delete the two namespaces afterwards and it does not.
- **From step 8 the Secret belongs to External Secrets.** The Hub chart renders an `ExternalSecret` with `creationPolicy: Owner`, which takes over `rhdh/rhdh-secrets` and refreshes it from Vault. Vault runs in `-dev` mode, in memory: if its pod restarts, run `deploy.sh` and `seed-vault.py` again, or the next refresh has nothing to read.

Do **not** apply `RHDH/argocd/apps/cnpg.yaml` or `RHDH/argocd/apps/developer-hub.yaml` together with the app-of-apps. Both repos can create the `Cluster` and the `Backstage` CR; only `rhdh-platform-gitops` should.

Three files hold the cluster domain, in four values. Miss one and the symptom is a Route that never admits (shard), a Dev Spaces dashboard on the wrong host, or Hub links that point at the old cluster.

## Verify

```bash
oc get csv -A | grep -Ev 'packageserver' | awk '{print $2, $NF}' | sort -u
oc get applications.argoproj.io -n openshift-gitops
oc -n rhdh get backstage,cluster.postgresql.cnpg.io,route
oc get istio,istiocni,ztunnel -A
oc -n openshift-devspaces get checluster
oc -n openshift-ingress-operator get ingresscontroller
```

## Tests

```bash
docs/lab-state/tests/test-docs.sh
```
