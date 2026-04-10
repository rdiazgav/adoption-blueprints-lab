# Workshop 03 — OpenShift Pipelines

Estimated total time: **90–120 minutes** | Difficulty: **Intermediate**

---

## Before You Begin

The pipeline pushes built images to **quay.io**. The six RetailFlow repositories must
exist in your Quay account before you run a pipeline for the first time.

```bash
export QUAY_USER=<your-quay-username>
export QUAY_TOKEN=<your-quay-api-token>   # Settings → CLI Password in quay.io
bash scripts/create-quay-repos.sh
```

This creates (or skips if already present) the following public repositories:

| Repository | Description |
|---|---|
| `quay.io/$QUAY_USER/retailflow-api-gateway` | RetailFlow api-gateway |
| `quay.io/$QUAY_USER/retailflow-orders` | RetailFlow orders |
| `quay.io/$QUAY_USER/retailflow-catalog` | RetailFlow catalog |
| `quay.io/$QUAY_USER/retailflow-payments` | RetailFlow payments |
| `quay.io/$QUAY_USER/retailflow-recommendations` | RetailFlow recommendations |
| `quay.io/$QUAY_USER/retailflow-frontend` | RetailFlow frontend |

> **Note:** `setup.sh` will prompt you to run this automatically as its first step.
> You can also run `create-quay-repos.sh` independently at any time — it is idempotent.

---

## Prerequisites

- **Workshop 00 completed** — RetailFlow deployed and all pods healthy in `retailflow`
- **OpenShift Pipelines operator installed** — or `setup.sh` will install it (step 1/5)
- `cluster-admin` permissions on OpenShift 4.14+ or CRC (≥ 16 GB RAM, 6 CPUs, 100 GB disk)
- `oc` CLI configured and logged in
- `tkn` CLI installed (`tkn version` should succeed)
- Quay.io account with write access to `quay.io/<your-user>/retailflow-*`

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

### 1 — Apply your Quay credentials secret

```bash
cp deploy/base/01-rbac/quay-credentials.yaml.template quay-credentials.yaml
# Edit quay-credentials.yaml — paste your base64-encoded docker config
oc apply -f quay-credentials.yaml -n retailflow
```

### 2 — Install operators, RBAC, workspaces, tasks, and pipelines

`setup.sh` automatically links `quay-credentials` to `pipeline-sa` after applying RBAC (step 3/5), so no manual `oc secret link` is needed.

```bash
cd workshops/03-pipelines
bash scripts/setup.sh
```

### 3 — Run the catalog pipeline manually

```bash
bash scripts/run-pipeline.sh catalog
```

---

## Running the Pipeline

### Setup (one time)

```bash
cd workshops/03-pipelines

# Optional: create Quay repos first
export QUAY_USER=<your-quay-username>
export QUAY_TOKEN=<your-quay-api-token>
bash scripts/create-quay-repos.sh

# Apply credentials, then run setup
cp deploy/base/01-rbac/quay-credentials.yaml.template quay-credentials.yaml
# Edit quay-credentials.yaml — paste your base64-encoded docker config
oc apply -f quay-credentials.yaml -n retailflow
bash scripts/setup.sh
```

After the operator reaches `Succeeded`, disable the affinity assistant (required for `volumeClaimTemplate` workspaces):

```bash
oc patch tektonconfig config --type merge \
  -p '{"spec":{"pipeline":{"coschedule":"disabled"}}}'
```

### Run a pipeline

```bash
# Quarkus service (uses maven-build + buildah-rootless)
bash scripts/run-pipeline.sh catalog

# Python / Node.js service (buildah-rootless only)
bash scripts/run-pipeline.sh recommendations
bash scripts/run-pipeline.sh frontend

# Watch logs
tkn pipelinerun logs -f --last -n retailflow
```

---

## Known Issues and Solutions (CRC)

These issues were encountered and resolved during end-to-end validation on CRC.

### 1 — Tekton Hub unreachable from cluster pods

**Symptom:** `git-clone` step fails with connection timeout to `api.hub.tekton.dev`.

**Solution:** `setup.sh` installs `git-clone` directly from `raw.githubusercontent.com`:
```bash
oc apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml -n retailflow
```
The `buildah` community task is replaced entirely by the custom `buildah-rootless` task in `03-tasks/`.

---

### 2 — PipelineRun stuck in `Pending` (coschedule / affinity assistant)

**Symptom:** PipelineRun stays `Pending` indefinitely when using `volumeClaimTemplate` for the source workspace.

**Root cause:** The Tekton affinity assistant requires all workspaces to share a single PVC when `coschedule` is enabled. `volumeClaimTemplate` creates per-PipelineRun PVCs, which breaks this assumption.

**Solution:**
```bash
oc patch tektonconfig config --type merge \
  -p '{"spec":{"pipeline":{"coschedule":"disabled"}}}'
```
This is idempotent and survives operator upgrades (unlike patching `feature-flags` ConfigMap directly, which the operator overwrites).

---

### 3 — Istio sidecar injected into Tekton TaskRun pods

**Symptom:** TaskRun pods time out or fail with mTLS errors because the Istio sidecar intercepts Maven download and Buildah network traffic.

**Solution (two layers):**

1. Annotate `pipeline-sa` ServiceAccount (`deploy/base/01-rbac/serviceaccount.yaml`):
   ```yaml
   annotations:
     sidecar.istio.io/inject: "false"
   ```
2. Set `taskRunTemplate.podTemplate` in every PipelineRun (`run-pipeline.sh`):
   ```yaml
   taskRunTemplate:
     podTemplate:
       metadata:
         annotations:
           sidecar.istio.io/inject: "false"
   ```

---

### 4 — Maven wrapper fails to download Maven distribution

**Symptom:** `./mvnw package` fails because `gzip` or `tar` is not available in `ubi9/openjdk-21`, or the SHA256 checksum does not match.

**Root cause:** The `maven-wrapper.properties` pointed to a non-existent Maven version (3.9.12). The `mvnw` script tries to download a `.tar.gz` which requires system `gzip`.

**Solution:**
- `maven-wrapper.properties` now points to `apache-maven-3.9.9-bin.zip` from Maven Central — the Maven wrapper extracts `.zip` using Java's built-in `ZipInputStream`, no system tools needed.
- `distributionSha256Sum` is removed to skip hash validation.
- `maven-build` Task sets `MVNW_REPOURL=https://repo.maven.apache.org/maven2` to pin the download base URL.

---

### 5 — Buildah fails with permission or overlay errors

**Symptom:** `buildah bud` fails with `permission denied`, `lchown`, or `overlay requires root` errors under restricted SCC.

**Root cause:** The community `buildah` Tekton task runs with `privileged: true` and uses the `overlay` storage driver, which requires kernel capabilities not available in OpenShift's restricted SCC.

**Solution:** Custom `buildah-rootless` task (`deploy/base/03-tasks/buildah-rootless.yaml`) using:

| Setting | Value | Why |
|---|---|---|
| Image | `quay.io/buildah/stable:v1.35` | Better rootless support than `ubi9/buildah` |
| `STORAGE_DRIVER` | `vfs` | No kernel overlay required; works with restricted SCC |
| `BUILDAH_ISOLATION` | `chroot` | Avoids user namespaces; works without `SETFCAP` |
| `CONTAINERS_STORAGE_CONF` | `/tmp/.config/containers/storage.conf` | Pins `ignore_chown_errors = "true"` at the storage layer |
| `capabilities.drop` | `ALL` | No Linux capabilities needed |
| `allowPrivilegeEscalation` | `false` | Compatible with restricted-v2 SCC |
| `emptyDir` at `/var/lib/containers` | — | Writable container storage without host bind mounts |

**SCC compatibility:** This configuration passes OpenShift's `restricted-v2` SCC and ACS (StackRox) image scanning policies without granting `anyuid` or `privileged` SCC to the pipeline service account.

---

## Repository Layout

```
workshops/03-pipelines/
├── README.md                        # This file
├── scripts/
│   ├── setup.sh                     # One-shot setup: operator + RBAC + workspaces + tasks + pipelines
│   ├── run-pipeline.sh              # Trigger a PipelineRun for any service
│   └── create-quay-repos.sh         # Create RetailFlow repos in quay.io via API (idempotent)
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
    │   │   └── pipeline-maven-cache-pvc.yaml  # source uses volumeClaimTemplate (ephemeral)
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
