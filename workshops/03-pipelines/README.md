# Workshop 03 — OpenShift Pipelines

Estimated total time: **90–120 minutes** | Difficulty: **Intermediate**

---

## Prerequisites

- **Workshop 00 completed** — RetailFlow deployed and all pods healthy in `retailflow`
- `cluster-admin` permissions on OpenShift 4.14+ or CRC (>= 16 GB RAM)
- `oc` CLI configured and logged in
- `tkn` CLI installed (`tkn version` should succeed)

---

## What You Will Learn

- How Tekton models CI/CD as Kubernetes-native resources (Task, Pipeline, PipelineRun)
- How to build and push a Quarkus service image using Buildah inside a Pipeline
- How to run Maven tests as a quality gate before the image is built
- How to build Python and Node.js services with a simpler, build-only pipeline
- How to wire a GitHub webhook to a Tekton EventListener so every `git push` triggers a PipelineRun automatically

---

## Narrative Context

Until now, deploying RetailFlow meant running `oc apply -k deploy/overlays/crc` by hand.
That works in a workshop — but in a real team, manual deploys are slow, error-prone, and invisible.
A developer commits a fix, hands off to operations, waits for a Slack message, hopes the right overlay was used.

This workshop replaces that workflow with an automated CI pipeline:
every push to the repository triggers a PipelineRun that clones the source, runs Maven tests, builds the container image with Buildah, pushes it to Quay, and updates the Deployment — all without human intervention.

Tekton is the engine. OpenShift Pipelines is the Red Hat–supported distribution.
Both are Kubernetes-native: every pipeline, task, and run is a regular API object you can inspect with `oc get`, monitor with `tkn`, and version-control alongside your application code.

---

## Architecture

```
Developer
    │
    │  git push
    ▼
GitHub repository
    │
    │  HTTP POST (webhook)
    ▼
OpenShift Route  ──► EventListener pod
                          │
                    Interceptors
                    (validate HMAC + filter branch)
                          │
                    TriggerBinding
                    (extract git-url, git-revision, service-name)
                          │
                    TriggerTemplate
                          │
                          ▼
                    PipelineRun created
                          │
          ┌───────────────┼───────────────────┐
          ▼               ▼                   ▼
     Task: git-clone  Task: maven-build  Task: buildah
     (Tekton Hub)     (custom)           (Tekton Hub)
          │               │                   │
          └───────────────┴───────────────────┘
                          │
                          ▼
                    Quay registry
                    (quay.io/rdiazgav/retailflow-<service>:<sha>)
                          │
                          ▼
                    Task: deploy-to-openshift
                    (oc set image + oc rollout status)
                          │
                          ▼
                    OpenShift Deployment updated
```

---

## Scenario Overview

| Level | Scenario | What Changes |
|-------|----------|--------------|
| 0 | Fundamentals | Explore Tekton CRDs; run a bare TaskRun by hand |
| 1 | First pipeline | Wire up the full CI pipeline for the `catalog` service end-to-end |
| 2 | Quality gates | Run Maven tests in the pipeline; understand shift-left testing |
| 3 | Multi-stack | Run Python and Node.js services through the `generic-service-pipeline` |
| 4 | Triggers | Configure a GitHub webhook so every `git push` launches a PipelineRun |

---

## Quick Start

### 1 — Install operators, RBAC, workspaces, tasks, and pipelines

```bash
cd workshops/03-pipelines
bash scripts/setup.sh
```

### 2 — Run the catalog pipeline manually

```bash
bash scripts/run-pipeline.sh catalog
```

---

## Repository Layout

```
workshops/03-pipelines/
├── README.md                        # This file
├── scripts/
│   ├── setup.sh                     # One-shot setup: operator + RBAC + workspaces + tasks + pipelines
│   └── run-pipeline.sh              # Trigger a PipelineRun for any service
└── deploy/
    ├── base/
    │   ├── 00-operators/
    │   │   ├── kustomization.yaml
    │   │   └── subscription.yaml         # OpenShift Pipelines operator
    │   ├── 01-rbac/
    │   │   ├── kustomization.yaml
    │   │   ├── serviceaccount.yaml       # pipeline-sa
    │   │   ├── role.yaml                 # pipeline-role
    │   │   ├── rolebinding.yaml
    │   │   ├── rolebinding-image-builder.yaml
    │   │   └── quay-credentials.yaml.template  # TEMPLATE — do not commit filled-in version
    │   ├── 02-workspaces/
    │   │   ├── kustomization.yaml
    │   │   ├── pipeline-source-pvc.yaml
    │   │   └── pipeline-maven-cache-pvc.yaml
    │   ├── 03-tasks/
    │   │   ├── kustomization.yaml
    │   │   ├── maven-build.yaml
    │   │   └── deploy-to-openshift.yaml
    │   ├── 04-pipelines/
    │   │   ├── kustomization.yaml
    │   │   ├── quarkus-service-pipeline.yaml
    │   │   ├── generic-service-pipeline.yaml
    │   │   ├── catalog-pipeline-run.yaml          # example — apply manually
    │   │   └── recommendations-pipeline-run.yaml  # example — apply manually
    │   └── 05-triggers/
    │       ├── kustomization.yaml
    │       ├── triggerbinding.yaml
    │       ├── triggertemplate.yaml
    │       ├── eventlistener.yaml
    │       ├── route.yaml
    │       └── github-webhook-secret.yaml.template  # TEMPLATE — do not commit filled-in version
    └── overlays/
        └── crc/
            ├── kustomization.yaml
            ├── pipeline-source-pvc-patch.yaml
            └── pipeline-maven-cache-pvc-patch.yaml
```

---

## Cleanup

To remove all pipeline resources while keeping RetailFlow running:

```bash
# Remove triggers
oc delete -k workshops/03-pipelines/deploy/base/05-triggers/ --ignore-not-found

# Remove pipelines and tasks
oc delete -k workshops/03-pipelines/deploy/base/04-pipelines/ --ignore-not-found
oc delete -k workshops/03-pipelines/deploy/base/03-tasks/ --ignore-not-found

# Remove workspaces (PVCs)
oc delete -k workshops/03-pipelines/deploy/base/02-workspaces/ --ignore-not-found

# Remove RBAC
oc delete -k workshops/03-pipelines/deploy/base/01-rbac/ --ignore-not-found
```

To remove the OpenShift Pipelines operator:

```bash
oc delete subscription openshift-pipelines-operator-rh -n openshift-operators
oc delete csv -l operators.coreos.com/openshift-pipelines-operator-rh.openshift-operators \
  -n openshift-operators
```
