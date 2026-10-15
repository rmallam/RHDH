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

`per-user` gives each developer **one** PVC shared by all their workspaces. This lab has only `gp3-csi`, which is RWO. ReadWriteOnce limits the volume to one **node**, not one pod: several workspace pods can mount it together as long as they are scheduled to the same node.

With `maxRunningWorkspacesPerUser: 1` there is only ever one workspace pod per user, so the question does not arise here. It is fragile in two ways once that changes. Raise the running limit and a second workspace that lands on a different node cannot attach the volume and waits in `ContainerCreating` with a multi-attach error; one that lands on the same node starts normally, so the failure looks intermittent. And an RWO EBS volume is tied to an availability zone, so a workspace can only restart on a node in the same zone. Use an RWX class when one exists and set `cheCluster.storage.accessModes` and `storageClass` to match.

### What NetworkPolicy does

`networkPolicy: true` makes the operator write policies into `openshift-devspaces` and into every user namespace. Check after first login:

```bash
oc -n openshift-devspaces get networkpolicy
oc -n <username>-devspaces get networkpolicy
```

User namespaces get `allow-from-openshift-devspaces`, `allow-from-devworkspace-operator`, `allow-from-openshift-ingress`, `allow-from-openshift-monitoring`, `allow-from-same-namespace` and `allow-all-egress`. Ingress is closed by default; **egress is open**. A workspace can reach anything the cluster can. Restricting egress is extra work the chart does not do.

### When the Che namespace denies egress

A customer cluster may already carry an egress-deny policy in the namespaces it creates. On sandbox3257 this was `deny-egress-to-other-namespaces` in `dw-ns-admin`. The Che gateway (port 3030) then cannot reach the editor (port 3100) in a workspace namespace, and the IDE never opens. Add one item under that policy's `spec.egress`, with no `ports` list, and leave the existing allows (DNS, authentication, the API server) as they are:

```yaml
- to:
    - namespaceSelector:
        matchLabels:
          app.kubernetes.io/component: workspaces-namespace
          app.kubernetes.io/part-of: che.eclipse.org
```

On the customer cluster the same item goes on the egress policy in their Che namespace (`openshift-devspaces` for a normal install). If a workspace namespace also denies ingress, it needs ingress from the Che namespace, from `openshift-ingress` (the IDE Route and health check) and from itself:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-workspace-ingress
  namespace: <username>-devspaces
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-ingress
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-devspaces   # the CheCluster namespace
    - from:
        - podSelector: {}
```

`spec.networking.networkPolicy.enabled: true` on the `CheCluster` makes the operator create equivalent policies itself.

### Mirroring the workspace image with its signature

When workspace images come from a mirror (Artifactory in a disconnected install), copy the signature with the image, or signature verification fails on the mirror. For the UDI:

```bash
SRC=registry.redhat.io/devspaces/udi-rhel9:3.30-1787764814
DST=artifactory.example.com/redhat/devspaces/udi-rhel9:3.30-1787764814
skopeo login registry.redhat.io
skopeo login artifactory.example.com
skopeo copy --all --preserve-digests docker://$SRC docker://$DST
DIGEST=$(skopeo inspect docker://$SRC | jq -r .Digest)
SIG=sha256-${DIGEST#sha256:}.sig
skopeo copy docker://registry.redhat.io/devspaces/udi-rhel9:$SIG \
  docker://artifactory.example.com/redhat/devspaces/udi-rhel9:$SIG
```

`--preserve-digests` keeps the digest the signature refers to. Source: `notes.md`.

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
| — | Second workspace stuck in `ContainerCreating` on `claim-devworkspace`, sometimes but not always | The RWO per-user volume is attached to another node. Pods on the same node share it; pods on different nodes cannot. Keep `maxRunningWorkspacesPerUser: 1` or move to RWX |
| — | Workspace will not restart after a node drain | RWO volume is in another availability zone |
| 2026-10-15 | IDE never opens; the Che gateway cannot reach the workspace on 3030 / 3100 | An egress-deny NetworkPolicy in the Che namespace. Add the workspace-namespace egress item above |
| — | Template "Open in Dev Spaces" links point at the wrong host | The Hub takes them from `devspacesBaseUrl` in `charts/developer-hub/values-deploy.yaml`. It is a separate value from the `CheCluster` domain and does not follow it |
