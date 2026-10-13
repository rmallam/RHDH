# OpenShift Dev Spaces on its own ingress shard

How Dev Spaces is configured on this lab, why it sits on a separate router, and which values to change on another cluster. Chart: `rmallam/rhdh-platform-gitops`, `charts/devspaces`. Shard: this repo, `tools/ingress-shard`.

**Update this file when a workspace fails to start, a limit changes, or the shard is rebuilt.**

## What runs on sandbox3257

| Piece | Value |
|---|---|
| Operator package | `devspaces`, channel `stable`, CSV `devspacesoperator.v3.30.2` |
| DevWorkspace operator | `devworkspace-operator.v0.43.0`, channel `fast` (installed as a dependency) |
| `CheCluster` | `devspaces` in `openshift-devspaces`, phase Active |
| Dashboard | `https://devspaces.devspaces.ocp.dkccw.sandbox3257.opentlc.com` |
| Workspace base domain | `devspaces.ocp.dkccw.sandbox3257.opentlc.com` |
| IngressController | `devspaces`, 1 replica, `LoadBalancerService`, selects `ingress.openshift.io/shard=devspaces` |
| Pods | `devspaces`, `devspaces-dashboard`, `che-gateway`, `plugin-registry` |
| User namespace | `<username>-devspaces`, created on first login (`autoProvision: true`) |

## CheCluster settings

Left column is the chart value in `charts/devspaces/values.yaml`. Right column is what the running `CheCluster` shows.

| Chart value | `CheCluster` field | Live |
|---|---|---|
| `cheCluster.namespaceTemplate` | `devEnvironments.defaultNamespace.template` | `<username>-devspaces` |
| `cheCluster.maxWorkspacesPerUser` | `devEnvironments.maxNumberOfWorkspacesPerUser` | `5` |
| `cheCluster.maxRunningWorkspacesPerUser` | `devEnvironments.maxNumberOfRunningWorkspacesPerUser` | `1` |
| `cheCluster.idleTimeoutSeconds` | `devEnvironments.secondsOfInactivityBeforeIdling` | `1800` |
| `cheCluster.runTimeoutSeconds` | `devEnvironments.secondsOfRunBeforeIdling` | `-1` (no cap) |
| `cheCluster.startTimeoutSeconds` | `devEnvironments.startTimeoutSeconds` | `300` |
| `cheCluster.defaultEditor` | `devEnvironments.defaultEditor` | `che-incubator/che-code/latest` |
| `cheCluster.disableContainerRunCapabilities` | `devEnvironments.disableContainerRunCapabilities` | `true` |
| `cheCluster.disableContainerBuildCapabilities` | `devEnvironments.disableContainerBuildCapabilities` | `false` |
| `cheCluster.containerBuildScc` | `devEnvironments.containerBuildConfiguration.openShiftSecurityContextConstraint` | `container-build` |
| `cheCluster.storage.pvcStrategy` | `devEnvironments.storage.pvcStrategy` | `per-user` |
| `cheCluster.storage.claimSize` | `…perUserStrategyPvcConfig.claimSize` | `10Gi` |
| `cheCluster.storage.accessModes` | `…perUserStrategyPvcConfig.storageAccessMode` | `ReadWriteOnce` |
| `networking.domain` | `networking.domain` | shard domain |
| `networking.labels` | `networking.labels` | `ingress.openshift.io/shard: devspaces` |
| `networking.networkPolicy` | `networking.networkPolicy.enabled` | `true` |
| `networking.allowGroups` | `networking.auth.advancedAuthorization.allowGroups` | unset — every authenticated user |
| (fixed in template) | `devEnvironments.persistUserHome.enabled` | `true` |
| (fixed in template) | `components.metrics.enable` | `true` |

Set by the operator, not the chart: `components.openVSXRegistry.enable: false`, `components.imagePuller.enable: false`.

### Container run versus container build

Two separate switches. Build is on: workspaces can run `podman build` under the `container-build` SCC, which the operator creates. Run is off: no nested containers, and the `container-run` SCC does not exist on this cluster. Turn run on only if developers must start containers inside a workspace; it needs the extra SCC and a wider security review.

### Storage: per-user on ReadWriteOnce

`per-user` gives each developer **one** PVC shared by all their workspaces. This lab has only `gp3-csi`, which is RWO. That works here for one reason: `maxRunningWorkspacesPerUser` is `1`, so the volume is never mounted by two pods at once.

It is fragile in two ways. Raise the running limit and the second workspace hangs in `ContainerCreating` on the volume. And an RWO EBS volume is tied to an availability zone, so a workspace can only restart on a node in the same zone. Use an RWX class when one exists and set `cheCluster.storage.accessModes` and `storageClass` to match.

### What NetworkPolicy does

`networkPolicy: true` makes the operator write policies into `openshift-devspaces` and into every user namespace. Check after first login:

```bash
oc -n openshift-devspaces get networkpolicy
oc -n <username>-devspaces get networkpolicy
```

User namespaces get `allow-from-openshift-devspaces`, `allow-from-devworkspace-operator`, `allow-from-openshift-ingress`, `allow-from-openshift-monitoring`, `allow-from-same-namespace` and `allow-all-egress`. Ingress is closed by default; **egress is open**. A workspace can reach anything the cluster can. Restricting egress is extra work the chart does not do.

## The ingress shard

Dev Spaces publishes a Route per workspace endpoint, on top of the dashboard. A shard keeps those off the default router and gives them their own wildcard domain and load balancer.

Four values in four files. They must agree.

| Object | File | Must match |
|---|---|---|
| `IngressController/devspaces` | `tools/ingress-shard/ingresscontroller.yaml` | `spec.domain`, `spec.routeSelector.matchLabels` |
| `IngressController/default` (patched) | `tools/ingress-shard/default-exclude-shard.yaml` | Excludes any Route carrying the shard label key |
| `CheCluster` | `charts/devspaces/values-deploy.yaml` | `networking.domain` = shard `spec.domain`; `networking.labels` = shard `routeSelector` |
| Hub links to Dev Spaces | `charts/developer-hub/values-deploy.yaml` | `devspacesBaseUrl` = `https://devspaces.<shard domain>` |

`default-exclude-shard.yaml` matters as much as the shard itself. Without it the default router also admits the Dev Spaces Routes and the two routers race for the same hosts.

The shard domain must be inside the cluster's public DNS zone and must **not** be the default apps domain. With `dnsManagementPolicy: Managed` the ingress operator publishes `*.devspaces.<base-domain>` at the shard's load balancer.

```bash
# Shard admitted, with its own load balancer
oc -n openshift-ingress-operator get ingresscontroller devspaces
oc -n openshift-ingress get svc router-devspaces

# Dashboard Route is on the shard and nowhere else
oc -n openshift-devspaces get route devspaces \
  -o jsonpath='{.metadata.labels.ingress\.openshift\.io/shard}{"  "}{.status.ingress[*].routerName}{"\n"}'
# expect: devspaces  devspaces
```

On a cluster with no spare public zone or load balancer, leave `networking.domain` empty and do not apply `tools/ingress-shard`. Dev Spaces then uses the default apps domain. Keep `default-exclude-shard.yaml` and the shard together: apply both or neither.

## Install on a new cluster

```bash
# 1. Operator from OperatorHub (package devspaces, channel stable)

# 2. Shard: edit spec.domain first
oc apply -k tools/ingress-shard
oc -n openshift-ingress-operator wait ingresscontroller/devspaces \
  --for=condition=Available --timeout=600s

# 3. CheCluster: set networking.domain in values-deploy.yaml to the same domain
oc apply -f rhdh-platform-gitops/argocd/apps/devspaces.yaml
oc -n openshift-devspaces wait checluster/devspaces \
  --for=jsonpath='{.status.chePhase}'=Active --timeout=900s
```

Apply the shard **before** the `CheCluster`. If the `CheCluster` comes first its Routes carry a label no router selects yet (once the default router has been patched) and the dashboard has no address until the shard is up.

## Production deltas

| Lab | Production |
|---|---|
| `defaultEditor: …/che-code/latest` | Pin an editor tag. `latest` follows the operator |
| Open VSX disabled, no extension source | Point `components.pluginRegistry.openVSXURL` at an approved mirror, or bake extensions into the editor image |
| No `containerRegistry` | Set the approved registry host and organisation for workspace images |
| `maxNumberOfWorkspacesPerUser: 5` | Set to the agreed limit |
| `startTimeoutSeconds: 300` | Raise it when images come from a mirror or the storage class is slow to attach |
| 30-minute idle, no cleanup | Idle timeout stops a workspace; it never deletes one. Stopped workspaces keep their PVC. Add a DevWorkspace cleanup job if workspaces must expire |
| RWO storage | RWX class |
| No proxy | Set `components.cheServer.proxy`, and `cheCluster.gitTrustedCertsConfigMapName` for an internal Git CA |
| `allowGroups` unset | Restrict the dashboard to named groups |
| No default container resources | Set requests and limits for workspace containers |
| Egress open from workspaces | Add an egress policy |
| Automatic approval, `openshift-operators` | Starting CSV, Manual approval, the namespace the platform team mandates |
| Shard with a public load balancer | Internal scope, corporate wildcard certificate (`networking.tlsSecretName`) |

## Verify

```bash
oc -n openshift-devspaces get checluster devspaces \
  -o jsonpath='{.status.chePhase}{"  "}{.status.cheVersion}{"  "}{.status.cheURL}{"\n"}'
oc -n openshift-devspaces get pods
oc get devworkspace -A
oc -n <username>-devspaces get pvc
```

## Tests

```bash
# in rmallam/rhdh-platform-gitops
charts/devspaces/tests/test-chart.sh
# here
docs/devspaces/tests/test-docs.sh
```

## Known issues

| When | Error | Fix |
|---|---|---|
| — | Dashboard Route has no host, or `oc get route` shows it admitted by no router | Shard not applied, shard label mismatch, or `networking.domain` differs from the shard's `spec.domain` |
| — | Dashboard reachable on two routers | `default-exclude-shard.yaml` not applied |
| — | Second workspace stuck in `ContainerCreating` on `claim-devworkspace` | RWO per-user volume already mounted. Keep `maxRunningWorkspacesPerUser: 1` or move to RWX |
| — | Workspace will not restart after a node drain | RWO volume is in another availability zone |
| — | Template "Open in Dev Spaces" links point at the wrong host | The Hub takes them from `devspacesBaseUrl` in `charts/developer-hub/values-deploy.yaml`. It is a separate value from the `CheCluster` domain and does not follow it |
