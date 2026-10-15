# Service Mesh 3 in ambient mode

What the mesh chart installs, how a namespace joins the mesh, and what still has to be built before this proves anything about traffic. Chart: `rmallam/rhdh-platform-gitops`, `charts/service-mesh`. Argo app: `service-mesh`.

**Update this file when a workload is enrolled, a policy is added, or an enrolment fails.** As of 2026-10-15 `routingViaHost` is `true` and one sample namespace, `bookinfo`, is enrolled with a waypoint. Its pods pass their probes under ztunnel and ztunnel logs show its connections completing. There is still no mTLS or authorization policy. **sandbox3257 expired on 2026-10-16**, and `bookinfo` and the `routingViaHost` patch were not in git, so both have to be redone on the new cluster. Read [Not proven yet](#not-proven-yet) before quoting this lab as evidence that ambient works.

## Hosted control planes (ROSA HCP, 2026-10-16)

The replacement lab is a ROSA cluster with hosted control planes, the same model as the customer's clusters. Two things are now shown on it:

- **`routingViaHost` can be set from the hosted cluster.** `oc patch networks.operator.openshift.io cluster …` with the hosted cluster's own kubeconfig was accepted, and both worker nodes report `mode: local` in their `k8s.ovn.org/l3-gateway-config` annotation. The field is also managed by `hosted-cluster-config-operator`, so check it is still `true` after a cluster upgrade.
- **The Hub and CloudNativePG run in ambient on it.** Namespace `rhdh` carries `istio.io/dataplane-mode: ambient`; the Hub pod and `rhdh-pg-1` are captured and Ready. On sandbox3257, before `routingViaHost` was set, the same enrolment left CloudNativePG never Ready.

This lab is deployed from `rmallam/RHDH-SM-DevSpaces`, not from `rhdh-platform-gitops`, so the Hub is enrolled there although `values-deploy.yaml` here keeps it out. No mesh policy exists yet.

## What runs on sandbox3257

| Piece | Value |
|---|---|
| Operator package | `servicemeshoperator3`, channel `stable`, CSV `servicemeshoperator3.v3.4.3` |
| Kiali operator | `kiali-ossm`, channel `stable`, CSV `kiali-operator.v2.27.5` |
| `Istio/default` | `sailoperator.io/v1`, `profile: ambient`, namespace `istio-system`, `v1.30.5`, `updateStrategy: InPlace` |
| `IstioCNI/default` | `sailoperator.io/v1`, `profile: ambient`, namespace `istio-cni`, `istioOwnedCNIConfig: true` |
| `ZTunnel/default` | `sailoperator.io/v1`, namespace `ztunnel` |
| `pilot.trustedZtunnelNamespace` | `ztunnel` — must equal the ZTunnel namespace. `ztunnel` is also the CRD default for `ZTunnel.spec.namespace` |
| `Kiali/kiali` | `istio-system`, `auth.strategy: anonymous`, Prometheus at `thanos-querier.openshift-monitoring.svc:9091` |
| Monitors | `ServiceMonitor/istiod-monitor` (`istio-system`), `PodMonitor/ztunnel-monitor` (`ztunnel`) |
| DaemonSets | `ztunnel` 6/6, `istio-cni-node` 6/6 |
| GatewayClasses | `istio`, `istio-waypoint`, `istio-remote` (created by istiod) |

`istio.version` is empty in `values.yaml`, so the operator chose `v1.30.5`. An operator upgrade can move it. Set `istio.version` and `istioCni.version` to freeze.

### ZTunnel API version

`ZTunnel` is stored as `sailoperator.io/v1`. That version has **no `spec.profile`**; ambient comes from the `Istio` CR. `sailoperator.io/v1alpha1` is still served and still accepts `spec.profile`, but it is deprecated and every apply prints a warning. Write new manifests against `v1`.

```bash
oc get crd ztunnels.sailoperator.io \
  -o jsonpath='{range .spec.versions[*]}{.name}{" served="}{.served}{" storage="}{.storage}{" deprecated="}{.deprecated}{"\n"}{end}'
```

The CRD also rejects any name other than `default` (`metadata.name must be 'default'`).

## Sync order

| Wave | Object |
|---|---|
| (app wave 1) | Application `service-mesh`, after `cnpg` (0), before `devspaces` (2) and `developer-hub` (3) |
| 2 | `IstioCNI` |
| 3 | `Istio`, `ZTunnel` |
| 4 | `Kiali`, `ServiceMonitor`, `PodMonitor`, `ClusterRoleBinding/kiali-cluster-monitoring-view` |

Namespaces `istio-system`, `istio-cni` and `ztunnel` are created by the chart (`createNamespaces: true`).

## How a namespace joins

Two labels, two different jobs.

| Label | Effect |
|---|---|
| `istio.io/dataplane-mode: ambient` | ztunnel captures pod traffic in the namespace: mTLS and L4 policy |
| `istio-discovery: enabled` | istiod **watches** the namespace. No traffic capture |

Both are `discoverySelectors` on the `Istio` CR, and selectors are OR-ed. So the ambient label alone is enough to discover **and** enrol. Use `istio-discovery: enabled` on its own for a namespace istiod must see but ztunnel must not touch — `istio-system` is labelled that way by the chart.

A namespace with neither label is invisible to the mesh. Its Services do not exist as far as istiod is concerned, and policy that names them matches nothing.

```bash
# Enrol
oc label namespace <ns> istio.io/dataplane-mode=ambient

# Check: pods are captured without a restart
oc -n <ns> get pods -o custom-columns='POD:.metadata.name,AMBIENT:.metadata.annotations.ambient\.istio\.io/redirection'
# expect: enabled

# Check: the Istio CR now counts the revision as in use
oc get istio default
```

Un-enrol by removing the label. No pod restart either way.

## Not proven yet

The control plane reconciles and both DaemonSets are ready. The first two rows have now been exercised; the rest have not.

| Gap | State on sandbox3257 (2026-10-15) | What to do |
|---|---|---|
| Enrolled workloads | `bookinfo` only, applied by hand (not in git). Its 6 pods carry `ambient.istio.io/redirection: enabled`, the namespace has `istio.io/use-waypoint: waypoint`, and `Istio/default` shows `IN USE 1` | Move `bookinfo` into `rhdh-platform-gitops`, then test policy on it. The Hub namespace stays out (`mesh.ambient: false`) |
| OVN-Kubernetes local gateway mode | `routingViaHost: true`, set by hand on 2026-10-14 | Done. Before it was set, kubelet probes to CloudNativePG port 8000 timed out when `rhdh` was captured. Make it a rebuild step |
| User workload monitoring | Off; no `cluster-monitoring-config` | The two monitors exist but nothing scrapes them, so Kiali has no mesh metrics. Enable it |
| STRICT mTLS | No `PeerAuthentication` | Ambient defaults to PERMISSIVE. Add a mesh-wide STRICT policy |
| Deny by default | No `AuthorizationPolicy` | Add an empty policy per enrolled namespace, then ALLOW rules |
| Waypoints | One, `Gateway/waypoint` in `bookinfo` (`istio.io/waypoint-for: service`), Programmed | Needed only for L7 policy or routing |
| Ingress | No `Gateway`, no gateway Deployment | Not built |
| Mesh CA | Self-signed istiod CA | No `cacerts` Secret |

### Local gateway mode

```bash
oc get networks.operator.openshift.io cluster \
  -o jsonpath='{.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.routingViaHost}{"\n"}'

oc patch networks.operator.openshift.io cluster --type=merge \
  -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"routingViaHost":true}}}}}'
```

This is cluster-scoped and rolls OVN-Kubernetes on every node. Wait for the network operator to settle before testing.

### User workload monitoring

```bash
oc apply -f - <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
YAML
oc -n openshift-user-workload-monitoring get pods
```

Kiali already reads `thanos-querier`, which serves platform and user-workload metrics together, and the chart already binds `kiali-service-account` to `cluster-monitoring-view`. Nothing else changes.

### Baseline policy

Apply after at least one workload is enrolled and its callers are known. Deny-all with no ALLOW rules stops all traffic to the namespace. STRICT refuses plaintext from clients outside the mesh, and the OpenShift router is outside the mesh: expect a plain Route to an enrolled workload (the Hub, for one) to stop answering until ingress goes through a mesh gateway or an explicit exception is made. Test this on a throwaway namespace first.

```yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system        # root namespace = mesh-wide
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: <enrolled-namespace>
spec: {}                          # no rules = deny everything
```

### Waypoint (only when L7 is needed)

ztunnel enforces L4: identity, mTLS, allow or deny by workload and port. Anything that reads HTTP — paths, methods, headers, retries, timeouts — needs a waypoint.

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: waypoint
  namespace: <enrolled-namespace>
  labels:
    istio.io/waypoint-for: service
spec:
  gatewayClassName: istio-waypoint
  listeners:
    - name: mesh
      port: 15008
      protocol: HBONE
```

```bash
oc label namespace <enrolled-namespace> istio.io/use-waypoint=waypoint
```

## Production deltas

| Lab | Production |
|---|---|
| Channel `stable`, Automatic approval | Minor-pinned channel (`stable-3.4`), starting CSV, Manual approval |
| Operators in `openshift-operators` | Whatever namespaces the platform team mandates; test that layout before relying on it |
| `istio.version: ""` | Pin `istio.version` and `istioCni.version` |
| ZTunnel in `ztunnel` (the CRD default for `spec.namespace`) | Decide the namespace once and keep `trustedZtunnelNamespace` equal to it. `Istio.spec.namespace` is immutable; `ZTunnel.spec.namespace` is not, but changing it replaces ztunnel on every node |
| Kiali `anonymous`, cluster-wide | `auth.strategy: openshift`; scope `accessible_namespaces` |
| Self-signed mesh CA | Plug in the corporate intermediate through `cacerts` |
| Argo controller is `cluster-admin` | Scope it |
| No policy | STRICT + deny-all through GitOps, per namespace |

## Verify

```bash
oc get istio,istiocni,ztunnel -A
oc -n ztunnel get ds ztunnel
oc -n istio-cni get ds istio-cni-node
oc get ns -l istio.io/dataplane-mode=ambient
oc get peerauthentication,authorizationpolicy -A
oc get gateways.gateway.networking.k8s.io -A
oc -n istio-system get route kiali
```

## Tests

```bash
# in rmallam/rhdh-platform-gitops
charts/service-mesh/tests/test-chart.sh
# here
docs/service-mesh-ambient/tests/test-docs.sh
```

## Known issues

| When | Error | Fix |
|---|---|---|
| 2026-10-14 | `rhdh` namespace loses `istio.io/dataplane-mode: ambient`; `developer-hub` Application stays OutOfSync on the Namespace; `Istio` shows `IN USE 0` | Both `charts/cnpg` and `charts/developer-hub` render `Namespace/rhdh`, and both Applications apply it as field manager `argocd-controller`. The last sync owns the labels. Set `createNamespace: false` in `charts/cnpg/values.yaml` so only the Hub chart owns the namespace. Since 2026-10-14 `values-deploy.yaml` sets `mesh.ambient: false`, so this no longer enrols the Hub; it only clears the OutOfSync |
| 2026-10-14 | CloudNativePG never Ready once `rhdh` was captured; kubelet probes to port 8000 time out | `routingViaHost` was `false`. It is now `true`. The Hub and its database are kept out of the mesh in any case |
| 2026-10-14 | Kiali graph empty | User workload monitoring is off, so the istiod and ztunnel monitors are not scraped. `bookinfo` traffic exists but Kiali has no metrics for it |
| — | `Warning: sailoperator.io/v1alpha1 ZTunnel is deprecated` | Manifest uses the old API. Move to `sailoperator.io/v1` and drop `spec.profile` |
| — | `The ZTunnel "<name>" is invalid: metadata.name must be 'default'` | The CRD allows one ZTunnel, named `default` |
| — | ztunnel rejects istiod, or workloads get no certificates | `pilot.trustedZtunnelNamespace` does not match the namespace in the `ZTunnel` CR |
