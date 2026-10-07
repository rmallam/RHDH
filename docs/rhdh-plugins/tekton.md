# Tekton

**Status:** partial (plugin loaded; no OpenShift Pipelines on this lab)

CI card when PipelineRuns exist for the same `kubernetes-id`.

## Required

| Layer | What |
|---|---|
| Helm | `plugins.tekton.enabled: true` |
| Package | community tekton OCI |
| ClusterRole | `tekton.dev` get/list/watch (already on `rhdh-kubernetes-reader`) |
| Catalog | same `backstage.io/kubernetes-id` as the PipelineRun labels |

This lab uses **Jenkins**, not Pipelines. Leave the plugin on so a customer cluster with Tekton lights up automatically.

## Known issues

| When | Error | Fix |
|---|---|---|
| this lab | Empty Tekton card | Expected — no `openshift-pipelines` operator |
