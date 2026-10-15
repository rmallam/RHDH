```
appConfig:
  auth:
    environment: development
    providers:
      guest:
        dangerouslyAllowOutsideDevelopment: true
  permission:
    enabled: true
    rbac:
      admin:
        users:
          - name: user:development/guest
  ```
```
spec:
  networking:
    hostname: devspaces.platform.example.com
    domain: platform.example.com
    labels:
      router: platform
```
```
https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.7/html/authentication_in_red_hat_developer_hub/enabling-user-authentication-with-microsoft-azure
```
```shell
The Dev Spaces install probes the public hostname before ExternalDNS has created the record. It creates a temporary Route, calls https://<hostname>, and deletes that Route in the same loop when the name does not resolve yet. The install stops there, and ExternalDNS never gets a stable Route to publish.

Two ways past that:

Create the DNS name first and point it at the router that will own the host, then apply the CheCluster.
Or set spec.networking.tlsSecretName to a Secret that already exists in the same namespace. That skips the probe. The Secret is type kubernetes.io/tls, with tls.crt and tls.key, and the label app.kubernetes.io/part-of=che.eclipse.org.
That Secret is the certificate the router serves for the ExternalDNS name. Its subject or SAN must include that hostname. A certificate for another name still lets the install finish, but browsers then fail TLS and login never starts.

Dev Spaces Routes are always edge TLS, with HTTP redirected to HTTPS. There is no setting for passthrough or re-encrypt. tlsSecretName only supplies the certificate on that edge Route.
```

```
On the hosted cluster kubeconfig:


oc patch networks.operator.openshift.io cluster --type=merge -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"routingViaHost":true}}}}}'
Check it:


oc get networks.operator.openshift.io cluster -o jsonpath='{.spec.defaultNetwork.ovnKubernetesConfig.gatewayConfig.routingViaHost}{"\n"}'
oc get clusteroperator network
Expect true, and network AVAILABLE=True / PROGRESSING=False after CNO finishes.

```
```
SRC=registry.redhat.io/devspaces/udi-rhel9:3.30-1787764814
DST=artifactory.example.com/redhat/devspaces/udi-rhel9:3.30-1787764814
skopeo login registry.redhat.io
skopeo login artifactory.example.com
skopeo copy --all --preserve-digests docker://$SRC docker://$DST
DIGEST=$(skopeo inspect docker://$SRC | jq -r .Digest)
SIG=sha256-${DIGEST#sha256:}.sig
skopeo copy \
  docker://registry.redhat.io/devspaces/udi-rhel9:$SIG \
  docker://artifactory.example.com/redhat/devspaces/udi-rhel9:$SIG

```
```
On this cluster the policy is deny-egress-to-other-namespaces in dw-ns-admin. Add this item under spec.egress:


- to:
    - namespaceSelector:
        matchLabels:
          app.kubernetes.io/component: workspaces-namespace
          app.kubernetes.io/part-of: che.eclipse.org
Leave the existing allows for dw-ns-admin, DNS, authentication, and the API server addresses as they are. Do not add a ports list on this rule. The gateway uses port 3030 and the editor uses port 3100.

On the customer cluster, put that same item on the egress policy in their Che namespace (openshift-devspaces for a normal install). If a workspace namespace also denies ingress, add this there too, with their Che namespace name:


apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-che-namespace
  namespace: <username>-devspaces
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: openshift-devspaces

```

```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-workspace-ingress
  namespace: <username>-devspaces
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
  ingress:
  # CRITICAL — IDE Route / health check
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-ingress
  # Control plane → workspace
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: openshift-devspaces   # use real CheCluster NS
  # Intra-namespace
  - from:
    - podSelector: {}
```
