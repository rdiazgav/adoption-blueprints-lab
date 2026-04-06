# Workshop 00 — Platform Setup

This workshop prepares your environment and deploys the RetailFlow base application.
It is a prerequisite for all other workshops.

Estimated time: **30–45 minutes**

---

## What you will do

- Verify your cluster meets the minimum requirements
- Install the base operators required by RetailFlow
- Deploy the RetailFlow application
- Verify that all services are running correctly

---

## Prerequisites

You need one of the following:

**Option A — Red Hat OpenShift Local (CRC)**

```bash
crc config set memory 16384
crc config set cpus 6
crc config set disk-size 100
crc start
```

Verify CRC is running:

```bash
crc status
```

**Expected output:**
```
CRC VM:          Running
OpenShift:       Running (v4.17.3)
RAM Usage:       7.42 of 15.96 GB
Disk Usage:      14.05 of 92.83 GB (Inside the CRC VM)
Cache Usage:     35.7 GB
Cache Directory: /Users/user/.crc/cache
```

**What to look for:**
- Both `CRC VM` and `OpenShift` must show `Running`
- RAM Usage should show headroom — if you are already above 14 GB before deploying anything, reduce other running applications

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `OpenShift: Stopped` | CRC started but OpenShift did not come up | Run `crc stop && crc start`, check `crc logs` |
| `CRC VM: Starting` hangs | Insufficient disk or memory | Verify host has 20+ GB free RAM and 120+ GB disk |
| `hypervisor not found` | Virtualization driver missing | Install HyperKit (macOS) or libvirt (Linux) |

**Option B — External OpenShift cluster**

You need:
- OpenShift 4.14 or later
- `cluster-admin` permissions
- At least 3 worker nodes with 8 vCPU / 16 GB RAM each
- A StorageClass with RWO support

---

## Step 1 — Connect to your cluster

**CRC:**

```bash
eval $(crc oc-env)
oc login -u developer -p developer https://api.crc.testing:6443
```

Verify access:

```bash
oc whoami
oc get nodes
```

**Expected output:**
```
developer
NAME                 STATUS   ROLES                         AGE   VERSION
crc-l7br4-master-0   Ready    control-plane,master,worker   18d   v1.30.4+6e0d669
```

**What to look for:**
- `oc whoami` returns your username (not an error)
- Node STATUS is `Ready` — any other value means the cluster is not healthy
- If using CRC, you will see a single node with `control-plane,master,worker` roles

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `error: dial tcp: connection refused` | CRC not fully started yet | Wait 2–3 minutes and retry |
| `The server uses a certificate signed by unknown authority` | Expired CRC cert | Run `crc stop && crc start` |
| `Unauthorized` | Wrong credentials | Use `-u kubeadmin` and the password from `crc console --credentials` |

**External cluster:**

```bash
oc login --token=<your-token> --server=https://<your-api-server>:6443
```

---

## Step 2 — Create the RetailFlow namespace

```bash
oc new-project retailflow
```

Verify the project was created:

```bash
oc project
```

**Expected output:**
```
Now using project "retailflow" on server "https://api.crc.testing:6443".
```

**What to look for:**
- The project name must be exactly `retailflow` — all workshop manifests hard-code this namespace

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `project "retailflow" already exists` | Namespace exists from a previous run | Run `oc project retailflow` to switch into it, or `oc delete project retailflow` to start fresh |
| `forbidden: unable to create project` | Insufficient permissions | Ask your cluster admin to create the namespace or grant you `self-provisioner` |

---

## Step 3 — Deploy RetailFlow

Clone the repository if you haven't already:

```bash
git clone https://github.com/rdiazgav/adoption-blueprints-lab.git
cd adoption-blueprints-lab
```

**CRC:**

```bash
oc apply -k deploy/overlays/crc
```

**Expected output:**
```
namespace/retailflow configured
configmap/retailflow-config created
serviceaccount/retailflow created
service/api-gateway created
service/catalog created
service/frontend created
service/orders created
service/payments created
service/postgresql-catalog created
service/postgresql-orders created
service/postgresql-payments created
service/recommendations created
service/redis created
deployment.apps/api-gateway created
deployment.apps/catalog created
deployment.apps/frontend created
deployment.apps/orders created
deployment.apps/payments-v1 created
deployment.apps/payments-v2 created
deployment.apps/postgresql-catalog created
deployment.apps/postgresql-orders created
deployment.apps/postgresql-payments created
deployment.apps/recommendations created
deployment.apps/redis created
persistentvolumeclaim/postgresql-catalog-pvc created
persistentvolumeclaim/postgresql-orders-pvc created
persistentvolumeclaim/postgresql-payments-pvc created
route.route.openshift.io/frontend created
```

**What to look for:**
- Every resource shows `created` or `configured` — not `error`
- All three PVCs are listed (CRC overlay includes persistent storage)

**External cluster:**

```bash
oc apply -k deploy/overlays/demo-platform
```

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `no matches for kind "Route"` | Not on OpenShift | Use `deploy/overlays/demo-platform` which uses Ingress instead |
| `unable to recognize "...": no matches for kind` | CRD not installed | The operator for that resource is missing — check operator prerequisites |
| `error: kustomize build failed` | Kustomize version mismatch | Use `oc apply -k` (built-in) not standalone `kustomize` |

---

## Step 4 — Verify the deployment

Wait for all pods to be ready:

```bash
oc get pods -n retailflow -w
```

**Expected output** (after 3–5 minutes on CRC):
```
NAME                                  READY   STATUS    RESTARTS   AGE
api-gateway-7d9f8b6c4-xk2pn           1/1     Running   0          4m12s
catalog-6c8d9f7b5-m9rvt               1/1     Running   0          4m10s
frontend-5b7c6d8f9-p4wzq              1/1     Running   0          4m11s
orders-8f6b5c7d4-t7jkn                1/1     Running   0          4m09s
payments-v1-9d7c8b6f5-h3mnp           1/1     Running   0          4m08s
payments-v2-4f8c7d9b6-r6lqx           1/1     Running   0          4m07s
postgresql-catalog-7b9c8d6f5-w2vks    1/1     Running   0          4m15s
postgresql-orders-6d8f7c9b4-n8ptr     1/1     Running   0          4m14s
postgresql-payments-5c9b8d7f6-k5wjm   1/1     Running   0          4m13s
recommendations-8c6d7f9b5-q9xtn       1/1     Running   0          4m06s
redis-7f9c8b6d5-v4zrp                 1/1     Running   0          4m16s
```

**What to look for:**
- `READY` column shows `1/1` for every pod — this means the container is up and the readiness probe is passing
- `STATUS` is `Running` for all pods
- `RESTARTS` should be 0 or low — more than 3 restarts indicates a crash loop

Verify all services are reachable:

```bash
oc get svc -n retailflow
```

**Expected output:**
```
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
api-gateway           ClusterIP   172.30.45.12     <none>        8080/TCP   5m
catalog               ClusterIP   172.30.112.88    <none>        8080/TCP   5m
frontend              ClusterIP   172.30.67.203    <none>        3000/TCP   5m
orders                ClusterIP   172.30.189.44    <none>        8080/TCP   5m
payments              ClusterIP   172.30.23.156    <none>        8080/TCP   5m
postgresql-catalog    ClusterIP   172.30.98.71     <none>        5432/TCP   5m
postgresql-orders     ClusterIP   172.30.145.33    <none>        5432/TCP   5m
postgresql-payments   ClusterIP   172.30.77.249    <none>        5432/TCP   5m
recommendations       ClusterIP   172.30.201.18    <none>        8000/TCP   5m
redis                 ClusterIP   172.30.134.62    <none>        6379/TCP   5m
```

**What to look for:**
- All services have a `CLUSTER-IP` assigned — `<pending>` or `<none>` on a ClusterIP service means it was not created
- Port numbers match expectations: Quarkus services on `8080`, recommendations on `8000`, Redis on `6379`

Verify PVCs are bound:

```bash
oc get pvc -n retailflow
```

**Expected output:**
```
NAME                      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgresql-catalog-pvc    Bound    pvc-3a7f2b1c-8d4e-4f6a-9b2c-1e5d7f8a3b4c   1Gi        RWO            crc-csi-hostpath-provisioner   5m
postgresql-orders-pvc     Bound    pvc-7b2c1d4e-5f8a-4c3b-8d6e-2f9a1b7c4d5e   1Gi        RWO            crc-csi-hostpath-provisioner   5m
postgresql-payments-pvc   Bound    pvc-1c4d5e6f-7a8b-4d2c-9e1f-3a5b8c2d7e6f   1Gi        RWO            crc-csi-hostpath-provisioner   5m
```

**What to look for:**
- `STATUS` must be `Bound` — `Pending` means no PersistentVolume could be provisioned

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| PVC stays `Pending` | No storage provisioner | On CRC, verify the `crc-csi-hostpath-provisioner` StorageClass exists: `oc get sc` |
| Pod stuck in `Init:0/1` | Init container waiting for DB | The PostgreSQL pod may still be starting — wait and retry |
| Pod in `CrashLoopBackOff` | Application error on startup | Check logs: `oc logs <pod-name> -n retailflow --previous` |

Get the frontend URL:

```bash
oc get route frontend -n retailflow -o jsonpath='{.spec.host}'
```

**Expected output:**
```
frontend-retailflow.apps-crc.testing
```

Open `https://frontend-retailflow.apps-crc.testing` in your browser — you should see the RetailFlow storefront.

---

## Step 5 — Smoke test

Run the smoke test script to verify all services are responding correctly:

```bash
./scripts/smoke-test.sh
```

**Expected output:**
```
RetailFlow smoke test
=====================
Cluster: https://api.crc.testing:6443
Namespace: retailflow

[OK] frontend           https://frontend-retailflow.apps-crc.testing         HTTP 200
[OK] api-gateway health http://api-gateway.retailflow.svc:8080/q/health/live  HTTP 200
[OK] orders health      http://orders.retailflow.svc:8080/q/health/live       HTTP 200
[OK] catalog health     http://catalog.retailflow.svc:8080/q/health/live      HTTP 200
[OK] payments health    http://payments.retailflow.svc:8080/q/health/live     HTTP 200
[OK] recommendations    http://recommendations.retailflow.svc:8000/health     HTTP 200

All services healthy.
```

**What to look for:**
- Every line shows `[OK]` and `HTTP 200`
- `[FAIL]` on any line means that service is not responding — check its pod logs

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `[FAIL] catalog — HTTP 000` | Pod not yet ready | Wait 30 seconds and re-run |
| `[FAIL] catalog — HTTP 500` | Database connection failed | Check PostgreSQL pod: `oc logs postgresql-catalog-xxx -n retailflow` |
| `[FAIL] recommendations — HTTP 503` | Python service crashed | Check logs: `oc logs recommendations-xxx -n retailflow` |
| `curl: (6) Could not resolve host` | DNS not resolving inside cluster | Verify CoreDNS pods are running: `oc get pods -n openshift-dns` |

---

## Troubleshooting

**Pods stuck in `Pending`**

Usually a resource constraint on CRC. Check node pressure:

```bash
oc describe node crc-l7br4-master-0 | grep -A5 "Conditions:"
oc describe node crc-l7br4-master-0 | grep -A10 "Allocated resources:"
```

If memory is the issue, verify your CRC config has at least 16384 MB and restart:

```bash
crc config get memory
crc stop && crc start
```

**Pods in `CrashLoopBackOff`**

Check logs for the failing pod:

```bash
oc get pods -n retailflow
oc logs <pod-name> -n retailflow --previous
```

**ImagePullBackOff**

Verify you have access to the registry:

```bash
oc get secret pull-secret -n retailflow
```

If missing, create it:

```bash
oc create secret docker-registry pull-secret \
  --docker-server=quay.io \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  -n retailflow

oc secrets link default pull-secret --for=pull -n retailflow
```

---

## What's next?

Your environment is ready. Choose your next workshop based on what you want to explore:

| I want to learn about... | Go to |
|---|---|
| Service mesh, traffic management, mTLS | [Workshop 01 — Service Mesh](../01-service-mesh/README.md) |
| Distributed tracing, logging, metrics | [Workshop 02 — Observability](../02-observability/README.md) |
| CI pipelines, automated builds | [Workshop 03 — Pipelines](../03-pipelines/README.md) |
| GitOps, declarative deployments | [Workshop 04 — GitOps](../04-gitops/README.md) |
| Identity, SSO, OIDC | [Workshop 05 — Keycloak](../05-keycloak/README.md) |
| Image registry, security scanning | [Workshop 06 — Quay](../06-quay/README.md) |
| Runtime security, CVE policies | [Workshop 07 — ACS](../07-acs/README.md) |
| Multi-cluster management | [Workshop 08 — ACM](../08-acm/README.md) |
| Developer portals, golden paths | [Workshop 09 — Developer Hub](../09-developer-hub/README.md) |
| AI/ML model serving | [Workshop 10 — OpenShift AI](../10-openshift-ai/README.md) |

Or follow the [full adoption journey](../../README.md#option-c--full-adoption-journey) from start to finish.
