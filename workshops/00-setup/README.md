# Workshop 00 — Platform setup

This workshop prepares your environment and deploys the RetailFlow base application. It is a prerequisite for all other workshops.

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

Expected output:

```
CRC VM:          Running
OpenShift:       Running (v4.1x.x)
RAM Usage:       ...
Disk Usage:      ...
```

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

Expected output for CRC:

```
NAME                 STATUS   ROLES                         AGE
crc-xxx-master-0     Ready    control-plane,master,worker   ...
```

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

Expected output:

```
Using project "retailflow" on server "https://...".
```

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

**External cluster:**

```bash
oc apply -k deploy/overlays/demo-platform
```

---

## Step 4 — Verify the deployment

Wait for all pods to be ready:

```bash
oc get pods -n retailflow -w
```

This may take 3–5 minutes on CRC. You should eventually see all pods in `Running` state:

```
NAME                               READY   STATUS    RESTARTS   AGE
api-gateway-xxxxxxxxx-xxxxx        1/1     Running   0          2m
catalog-xxxxxxxxx-xxxxx            1/1     Running   0          2m
frontend-xxxxxxxxx-xxxxx           1/1     Running   0          2m
orders-xxxxxxxxx-xxxxx             1/1     Running   0          2m
payments-v1-xxxxxxxxx-xxxxx        1/1     Running   0          2m
payments-v2-xxxxxxxxx-xxxxx        1/1     Running   0          2m
recommendations-xxxxxxxxx-xxxxx    1/1     Running   0          2m
postgresql-orders-xxxxxxx-xxxxx    1/1     Running   0          3m
postgresql-catalog-xxxxxxx-xxxxx   1/1     Running   0          3m
redis-xxxxxxxxx-xxxxx              1/1     Running   0          3m
```

Verify all services are reachable:

```bash
oc get svc -n retailflow
```

Get the frontend URL:

```bash
oc get route frontend -n retailflow -o jsonpath='{.spec.host}'
```

Open the URL in your browser — you should see the RetailFlow storefront.

---

## Step 5 — Smoke test

Run the smoke test script to verify all services are responding correctly:

```bash
./scripts/smoke-test.sh
```

Expected output:

```
[OK] frontend        — HTTP 200
[OK] api-gateway     — HTTP 200
[OK] orders          — HTTP 200 /q/health
[OK] catalog         — HTTP 200 /q/health
[OK] payments-v1     — HTTP 200 /q/health
[OK] payments-v2     — HTTP 200 /q/health
[OK] recommendations — HTTP 200 /health
```

If any service returns a non-200 status, check the pod logs:

```bash
oc logs -l app=<service-name> -n retailflow
```

---

## Troubleshooting

**Pods stuck in `Pending`**

Usually a resource constraint on CRC. Check node pressure:

```bash
oc describe node crc-xxx-master-0 | grep -A5 "Conditions:"
oc describe node crc-xxx-master-0 | grep -A10 "Allocated resources:"
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
