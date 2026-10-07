# RHDH dynamic plugins in a disconnected environment

RHDH 1.10 loads plugins in the `install-dynamic-plugins` **init container** using **skopeo**, not the kubelet. Cluster `ImageDigestMirrorSet` / `ImageContentSourcePolicy` **do not** rewrite those pulls. You must either:

1. Mirror the OCI artifacts to the internal registry **and** mount a `registries.conf` into that init container, or
2. Change every `package: oci://…` URL in `dynamic-plugins.yaml` to the internal registry.

Prefer (1). Then GitOps keeps the public `oci://` references and the init container transparently pulls from the mirror.

```
docs/rhdh-disconnected-plugins/
  README.md
  plugins-oci.txt                 ← extra community OCI refs used by this platform
  scripts/mirror-customer-plugins.sh
  manifests/
    rhdh-mirror-conf.yaml         ← registries.conf for the init container
    backstage-plugin-mirror-patch.yaml
    dynamic-plugins.yaml          ← enable bundled + OCI plugins
```

---

## 1. Two kinds of plugin (do not mix them up)

| Kind | `package:` value | Disconnected action |
|---|---|---|
| **Bundled** | `./dynamic-plugins/dist/…` | None. Already inside the RHDH operand image. Mirror **that image** with `oc-mirror` like any other OpenShift payload. |
| **OCI** | `oci://registry…/name:tag` | Mirror the artifact to the internal registry. Mount `registries.conf` on `install-dynamic-plugins`. |

The **full Westpac install list** is `manifests/dynamic-plugins.yaml` (and the table in `plugins-inventory.md`). `plugins-oci.txt` is only the GHCR artifacts that are **not** inside the RHDH image. Jenkins is required and **is** enabled (`./dynamic-plugins/dist/backstage-community-plugin-jenkins*`); it is omitted from `plugins-oci.txt` on purpose.

OCI extras that **must** be mirrored for WNZL: Argo CD, SonarQube, Snyk, Jira, Artifactory, Tekton, **Vault**, **ServiceNow**, **Dynatrace** (+ DQL), **IBM API Connect**.

Also mirror the **RHDH 1.10 plugin catalog index** so GA/TP plugins from Red Hat resolve without the internet:

`oci://registry.access.redhat.com/rhdh/plugin-catalog-index:1.10`

Match the index tag to the operator version (this ROSA demo is **1.10**). The GHCR overlay tags in GitOps (`bs_1.45.3__…`) are RHDH 1.9-era community builds; keep them only if that overlay still loads on 1.10, otherwise retag from the [Dynamic plugins reference](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.10/html/release_notes/rhdh-release-notes) / plugin catalog for 1.10.

---

## 2. What you need on the connected bastion

- `skopeo` ≥ 1.20, GNU `tar` ≥ 1.35, `jq` ≥ 1.7, `podman`
- Login to sources **and** (if partially disconnected) the internal registry

```bash
podman login registry.redhat.io          # or registry.access.redhat.com
podman login ghcr.io                     # if pulling community overlays
podman login registry.internal.example.com
```

Download Red Hat’s script (do not rewrite it):

```bash
curl -sSLO https://raw.githubusercontent.com/redhat-developer/rhdh-operator/refs/heads/release-1.10/.rhdh/scripts/mirror-plugins.sh
chmod +x mirror-plugins.sh
```

---

## 3. Copy OCI plugins into the internal registry

### Fully disconnected (export → sneakernet → import)

**On a connected host:**

```bash
bash mirror-plugins.sh \
  --plugin-index oci://registry.access.redhat.com/rhdh/plugin-catalog-index:1.10 \
  --plugin-list docs/rhdh-disconnected-plugins/plugins-oci.txt \
  --to-dir /var/tmp/rhdh-plugin-mirror
```

Copy `/var/tmp/rhdh-plugin-mirror` (USB, approved transfer) into the bank network.

**On a host that can reach only the internal registry:**

```bash
podman login registry.internal.example.com
bash mirror-plugins.sh \
  --from-dir /var/tmp/rhdh-plugin-mirror \
  --to-registry registry.internal.example.com
```

The script writes `rhdh-plugin-mirroring-summary.txt` (source → mirror mapping). Keep that file with the change record.

### Partially disconnected (bastion can reach both)

```bash
bash mirror-plugins.sh \
  --plugin-index oci://registry.access.redhat.com/rhdh/plugin-catalog-index:1.10 \
  --plugin-list docs/rhdh-disconnected-plugins/plugins-oci.txt \
  --to-registry registry.internal.example.com
```

### Only the nine community overlays (no catalog index)

If the customer will not take the full Red Hat index, use the wrapper (skopeo + podman auth):

```bash
export INTERNAL_REGISTRY=registry.internal.example.com
./docs/rhdh-disconnected-plugins/scripts/mirror-customer-plugins.sh export /var/tmp/rhdh-oci
# transfer the dir, then:
./docs/rhdh-disconnected-plugins/scripts/mirror-customer-plugins.sh import /var/tmp/rhdh-oci
```

OpenShift’s **in-cluster** registry only allows two path segments. Red Hat’s script flattens `ghcr.io/redhat-developer/rhdh-plugin-export-overlays/<plugin>` automatically. A corporate Harbor/Artifactory usually keeps the full path — set `registries.conf` `location` to match what was actually pushed.

---

## 4. Teach RHDH to pull from the mirror (install)

`install-dynamic-plugins` uses containers/image (`registries.conf`), not ICSP.

1. Edit `manifests/rhdh-mirror-conf.yaml` — replace `registry.internal.example.com` with the customer registry.
2. Apply it in the RHDH namespace.
3. Merge `manifests/backstage-plugin-mirror-patch.yaml` into the live Backstage CR (`extraFiles` on **`install-dynamic-plugins` only**).
4. If the registry needs a pull secret:

```bash
oc -n rhdh create secret docker-registry internal-registry-auth \
  --docker-server=registry.internal.example.com \
  --docker-username=... --docker-password=...
```

Mount `.dockerconfigjson` on that same init container and set `REGISTRY_AUTH_FILE` (see comments in the patch YAML).

5. If the registry uses a corporate CA, mount the CA ConfigMap into `install-dynamic-plugins` (see Red Hat “custom certificates” for OCI plugins). Cluster-wide trusted CAs are **not** enough by themselves.

6. Apply `manifests/dynamic-plugins.yaml` as ConfigMap `dynamic-plugins-rhdh` and keep `spec.application.dynamicPluginsConfigMapName: dynamic-plugins-rhdh`.

Leave `package: oci://ghcr.io/…` and `oci://registry.access.redhat.com/…` **unchanged**. `registries.conf` rewrites the pull.

---

## 5. Also mirror the RHDH operand image

Bundled plugins (`./dynamic-plugins/dist/…`) travel with:

`registry.redhat.io/rhdh/rhdh-hub-rhel9:<version>`

Include that image (and the operator) in the normal OpenShift disconnected mirror (`oc-mirror`). That is separate from plugin OCI artifacts.

---

## 6. Prove it is disconnected

```bash
# Init container must not time out on ghcr.io / registry.redhat.io
oc -n rhdh logs deploy/backstage-developer-hub -c install-dynamic-plugins

# Loaded set
curl -sS https://<rhdh-host>/api/dynamic-plugins-info/loaded-plugins | jq '.[].name'
```

You want Tekton, Argo CD, SonarQube, Snyk, Jira, Artifactory, Jenkins, Kubernetes, LDAP, RBAC in that list, and **no** `i/o timeout` / `connection refused` to public registries.

---

## 7. What not to do

- Do not point `package:` at `npm:` / the public npm registry in a bank network unless they have an internal npm proxy **and** an `.npmrc` mounted at `/opt/app-root/src/.npmrc.dynamic-plugins` (Operator does not auto-detect Helm’s secret name).
- Do not rely on `ImageDigestMirrorSet` for plugins.
- Do not put registry passwords in Git. Use `rhdh-secrets.example.yaml` style secrets only.
- Do not assign `role:default/rbac_admin` from the plugin CSV; that stays in app-config.

---

## Official references

- [Install dynamic plugins (RHDH 1.10)](https://docs.redhat.com/en/documentation/red_hat_developer_hub/1.10/html/installing_and_viewing_plugins_in_red_hat_developer_hub/install-dynamic-plugins-in-rhdh_installing-and-viewing-plugins-in-rhdh) §1.7–1.8
- [Operator example `plugin-mirroring.yaml`](https://github.com/redhat-developer/rhdh-operator/blob/release-1.10/examples/plugin-mirroring.yaml)
- [mirror-plugins.sh (release-1.10)](https://github.com/redhat-developer/rhdh-operator/blob/release-1.10/.rhdh/scripts/mirror-plugins.sh)
