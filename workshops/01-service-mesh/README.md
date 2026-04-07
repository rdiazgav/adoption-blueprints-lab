# Workshop 01 — Service Mesh with OpenShift Service Mesh 3.x

This workshop installs OpenShift Service Mesh 3.x (Sail Operator) on top of the
RetailFlow application and walks through five progressive scenarios that demonstrate
the core value of a service mesh: visibility, secure ingress, traffic control, failure
isolation, and zero-trust authorization.

Estimated total time: **60–90 minutes**

---

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ OpenShift Router (edge TLS termination)                     │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS → HTTP
                      ▼
┌─────────────────────────────────────────────────────────────┐
│ Namespace: istio-ingress                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Gateway API (cloudhop-gateway)                      │  │
│  │  istio-ingressgateway pod  [Envoy]                   │  │
│  └──────────────────────┬───────────────────────────────┘  │
└─────────────────────────┼───────────────────────────────────┘
                          │ HTTPRoute → frontend:3000
                          ▼
┌─────────────────────────────────────────────────────────────┐
│ Namespace: retailflow  (mTLS STRICT, sidecar injected)      │
│                                                             │
│  [frontend]──────► [api-gateway]                            │
│                         │                                   │
│             ┌───────────┼────────────────┐                  │
│             ▼           ▼                ▼                  │
│         [orders]    [catalog]    [recommendations]          │
│             │           │                                   │
│             ▼           ▼                                   │
│        [payments]  [postgresql]                             │
│        v1 (90%)                                             │
│        v2 (10%)                                             │
│                                                             │
│  Every arrow = mTLS-encrypted, Envoy-proxied connection     │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- **Workshop 00 completed** — RetailFlow deployed and all pods healthy in `retailflow`
- `cluster-admin` permissions on OpenShift 4.14+ or CRC (>= 16 GB RAM)
- `oc` CLI configured and logged in

Verify the baseline before starting:

```bash
oc get pods -n retailflow --field-selector=status.phase=Running | wc -l
# Expected: 11 or more running pods
```

---

## Apply everything at once

To deploy all mesh resources in a single command:

```bash
oc apply -k workshops/01-service-mesh/deploy/overlays/crc
```

Then follow the verification steps in each scenario below to understand what was deployed.

## Apply scenario by scenario

Each scenario builds on the previous one. Apply them in order for a guided experience:

| Scenario | Resources | Apply command |
|---|---|---|
| 1 — Mesh entry | Operators, control plane, namespace labels | See Step 1 below |
| 2 — Ingress gateway | Gateway API + Route | Included in Step 1 |
| 3 — Canary release | DestinationRule + VirtualService for payments | `03-traffic/payments-*.yaml` |
| 4 — Circuit breaker | DestinationRule + VirtualService for catalog | `03-traffic/catalog-*.yaml` |
| 5 — Authorization | AuthorizationPolicy for payments | `03-traffic/authz-payments.yaml` |

---

## Step 1 — Install the mesh

```bash
oc apply -k workshops/01-service-mesh/deploy/overlays/crc
```

Wait for operators:

```bash
oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -l operators.coreos.com/sailoperator.openshift-operators \
  -n openshift-operators --timeout=300s

oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -l operators.coreos.com/kiali-ossm.openshift-operators \
  -n openshift-operators --timeout=300s
```

Wait for istiod:

```bash
oc wait --for=condition=Ready pod -l app=istiod \
  -n istio-system --timeout=180s
```

Restart retailflow pods to inject sidecars:

```bash
oc rollout restart deployment -n retailflow
oc rollout status deployment/api-gateway -n retailflow
```

---

---

## Scenario 1 — Mesh entry: visibility and mTLS

Estimated time: **10 minutes**

### What is this?

When you add a service mesh, every pod gets a sidecar proxy (Envoy) injected
automatically. All traffic between services flows through these proxies, giving
you encryption, metrics, and tracing without changing a single line of
application code.

### The problem it solves

Without a mesh, service-to-service traffic is invisible. An operations team
managing CloudHop Travel has no way to answer basic questions: which services
call which others? How long do calls take? Are there errors? Is traffic
encrypted in transit? They can only find out when a customer complains.

### How it works in CloudHop Travel

Every RetailFlow pod (api-gateway, catalog, orders, payments, recommendations,
frontend) gets an Envoy sidecar injected at startup. The `retailflow` namespace
is labelled `istio-injection: enabled`, and each Deployment has
`sidecar.istio.io/inject: "true"` in its pod template for explicit control.

Once injected, all calls between services — for example, api-gateway calling
catalog to list destinations — are automatically encrypted with mTLS. Neither
service needs to configure TLS. The proxies handle the certificate lifecycle
using Istio's built-in CA.

### What you will see in Kiali

1. Open Kiali: `https://$(oc get route kiali -n istio-system -o jsonpath='{.spec.host}')`
2. Navigate to **Graph** → select namespace `retailflow` → set time range to **Last 1m**
3. Generate traffic so the graph populates:

```bash
oc port-forward deployment/api-gateway 8080:8080 -n retailflow &
PF_PID=$!
sleep 2
for i in $(seq 1 20); do
  curl -s http://localhost:8080/api/products > /dev/null
  curl -s http://localhost:8080/api/orders > /dev/null
done
kill $PF_PID 2>/dev/null
```

You should see:
- All services as nodes connected by directed edges
- **Lock icons** on edges — these indicate mTLS is active on that connection
- Request rates (RPS) and error percentages on each edge
- The full call graph: frontend → api-gateway → catalog/orders/recommendations → payments/databases

### Verify

```bash
# All pods should show 2/2 (app container + istio-proxy)
oc get pods -n retailflow

# Confirm container names
oc get pods -n retailflow \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

**Expected output:**
```
api-gateway-7d9f8b6c4-xk2pn      api-gateway istio-proxy
catalog-6c8d9f7b5-m9rvt          catalog istio-proxy
frontend-5b7c6d8f9-p4wzq         frontend istio-proxy
orders-8f6b5c7d4-t7jkn           orders istio-proxy
payments-v1-9d7c8b6f5-h3mnp      payments istio-proxy
payments-v2-4f8c7d9b6-r6lqx      payments istio-proxy
postgresql-catalog-7b9c8d6f5-w2vks  postgresql
postgresql-orders-6d8f7c9b4-n8ptr   postgresql
postgresql-payments-5c9b8d7f6-k5wjm postgresql
recommendations-8c6d7f9b5-q9xtn  recommendations istio-proxy
redis-7f9c8b6d5-v4zrp            redis
```

### What to look for

- Application pods show `2/2` — the second container is `istio-proxy`
- PostgreSQL and Redis show `1/1` — they are excluded from injection (no mesh label on those pod templates)
- In Kiali, lock icons appear on every service-to-service edge
- The `default` PeerAuthentication shows STRICT mode:

```bash
oc get peerauthentication -n retailflow
# NAME      MODE     AGE
# default   STRICT   5m
```

---

## Scenario 2 — Ingress Gateway: controlled mesh entry

Estimated time: **10 minutes**

### What is this?

An ingress gateway is the single controlled entry point into the mesh from
outside the cluster. All external traffic enters through it, meaning Envoy
applies policies — routing rules, TLS, rate limits — before the request ever
reaches an application pod.

### The problem it solves

Without a gateway, external requests reach application pods directly through
OpenShift Routes. Those routes bypass the mesh entirely: no mTLS, no Envoy
metrics, no traffic policies. A customer hitting `cloudhop-mesh.apps-crc.testing`
and a service inside the mesh calling another service would be treated
completely differently — one is invisible to the mesh, one is not.

### How it works in CloudHop Travel

A `Gateway` resource (Gateway API) is deployed in `istio-ingress`. It listens
on port 80 and allows routes from all namespaces. An `HTTPRoute` in `retailflow`
attaches to this gateway and routes all traffic for `cloudhop-mesh.apps-crc.testing`
to the `frontend` service on port 3000.

An OpenShift `Route` points to the `cloudhop-gateway-istio` Service (auto-created
by the Sail Operator's Gateway controller) with edge TLS termination and HTTP→HTTPS
redirect.

### What you will see in Kiali

After sending external traffic through the route:
- A gateway node appears at the edge of the graph
- An edge from the gateway to `frontend` shows the incoming request rate
- You can see end-to-end latency from the browser to the backend services

### Apply

The gateway resources are included in the base overlay. Verify the route exists:

```bash
oc get route cloudhop-mesh -n istio-ingress
oc get gateway cloudhop-gateway -n istio-ingress
oc get httproute cloudhop-frontend -n retailflow
```

### Verify

```bash
# Check the gateway pod is running and injected
oc get pods -n istio-ingress

# Check the route hostname
oc get route cloudhop-mesh -n istio-ingress \
  -o jsonpath='{.spec.host}'
```

**Expected output:**
```
NAME                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-xxx-yyy   1/1   Running   0   10m

cloudhop-mesh.apps-crc.testing
```

Test the gateway end-to-end:

```bash
curl -sk https://cloudhop-mesh.apps-crc.testing/health
```

**Expected output:**
```json
{"status":"ok","service":"frontend"}
```

### What to look for

- The gateway pod shows `1/1` — it uses gateway injection mode (the proxy IS the container, no app container alongside it)
- The Route uses `termination: edge` — TLS ends at the OpenShift router, the gateway receives plain HTTP on port 80
- The `HTTPRoute` status shows `Accepted`:

```bash
oc get httproute cloudhop-frontend -n retailflow \
  -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}'
# Expected: True
```

---

## Scenario 3 — Canary release: payments v1/v2 with 90/10 split

Estimated time: **10 minutes**

### What is this?

A canary release sends a small percentage of real traffic to a new version of
a service while the majority still goes to the stable version. If the new version
has a problem, only a fraction of users are affected and you can roll back instantly
by updating the traffic weights.

### The problem it solves

CloudHop Travel is releasing payments v2, which includes a new fraud detection
algorithm. Deploying it to 100% of users immediately is risky — if there is a
bug in the payment flow, every transaction fails. A canary lets the team validate
v2 with 10% of real bookings before committing to a full rollout.

### How it works in CloudHop Travel

Two Deployments exist: `payments-v1` and `payments-v2`. They share a single
`payments` Kubernetes Service. Without a mesh, the Service would load-balance
50/50. With the mesh:

- A `DestinationRule` defines two subsets: `v1` (label `app.kubernetes.io/version: v1`)
  and `v2` (label `app.kubernetes.io/version: v2`)
- A `VirtualService` routes 90% of traffic to `v1` and 10% to `v2`

Envoy enforces the weights at the client proxy side, before the request leaves
the calling pod.

### What you will see in Kiali

1. In the Graph view, the `payments` node expands to show `payments v1` and `payments v2`
2. Edge labels show the approximate split: roughly 9 requests to v1 for every 1 to v2
3. Both versions show a green health indicator

### Apply

The resources are already applied as part of the base overlay. Confirm:

```bash
oc get destinationrule payments -n retailflow
oc get virtualservice payments -n retailflow
```

### Verify

Generate 50 payment requests and observe the split:

```bash
oc port-forward deployment/api-gateway 8080:8080 -n retailflow &
PF_PID=$!
sleep 2

V1=0; V2=0
for i in $(seq 1 50); do
  RESP=$(curl -s -X POST http://localhost:8080/api/payments \
    -H "Content-Type: application/json" \
    -d '{"orderId":1,"amount":99.99,"currency":"USD"}')
  if echo "$RESP" | grep -q '"version":"v2"'; then
    V2=$((V2 + 1))
  else
    V1=$((V1 + 1))
  fi
done

kill $PF_PID 2>/dev/null
echo "v1: $V1 / v2: $V2 (out of 50)"
```

**Expected output** (approximate — weights are probabilistic):
```
v1: 44 / v2: 6 (out of 50)
```

Check the VirtualService weights:

```bash
oc get virtualservice payments -n retailflow \
  -o jsonpath='{.spec.http[0].route[*].weight}'
# Expected: 90 10
```

### What to look for

- `v1` receives approximately 90% of requests, `v2` approximately 10%
- Both subsets are healthy (green in Kiali)
- To shift more traffic to v2 (e.g. 50/50), edit the VirtualService weights:

```bash
oc patch virtualservice payments -n retailflow \
  --type=json \
  -p='[{"op":"replace","path":"/spec/http/0/route/0/weight","value":50},
       {"op":"replace","path":"/spec/http/0/route/1/weight","value":50}]'
```

---

## Scenario 4 — Circuit breaker: catalog failure isolation

Estimated time: **15 minutes**

### What is this?

A circuit breaker detects when a downstream service is repeatedly failing and
"opens the circuit" — stopping requests to the unhealthy service for a
configurable period instead of letting them pile up. After the ejection period,
a small percentage of requests are allowed through to test recovery.

### The problem it solves

The CloudHop catalog is the most-called service in the platform: every page load,
every search, every recommendation refresh hits it. If the catalog pod develops
a memory leak and starts returning 503 errors, without a circuit breaker those
errors cascade: the api-gateway queues requests, threads block waiting for
responses, and within minutes the api-gateway itself becomes unresponsive — taking
down bookings and payments even though their pods are perfectly healthy.

### How it works in CloudHop Travel

The `catalog` DestinationRule is configured with `outlierDetection`:

- After **3 consecutive 5xx or gateway errors**, the catalog host is ejected
- It stays ejected for **30 seconds** (`baseEjectionTime`)
- Up to **100% of hosts** can be ejected (`maxEjectionPercent: 100`)

The `catalog` VirtualService adds:
- A **3-second timeout** on all catalog calls
- **2 retry attempts** on `gateway-error`, `connect-failure`, or `retriable-4xx`

The catalog service has a `/chaos` toggle endpoint that makes it return 503
without killing the pod, so Envoy sees real HTTP errors and triggers the ejection.

### What you will see in Kiali

During chaos:
- The `catalog` node turns **red or orange**
- Edge labels show a high error percentage (e.g. `503 100%`)
- The `catalog` service sidebar shows an outlier ejection event

After recovery (30 seconds):
- The node returns to green
- Error rate drops to 0%
- Traffic resumes normally

### Apply

The circuit breaker resources are already applied. Verify:

```bash
oc get destinationrule catalog -n retailflow \
  -o jsonpath='{.spec.trafficPolicy.outlierDetection}'

oc get virtualservice catalog -n retailflow \
  -o jsonpath='{.spec.http[0].timeout}'
# Expected: 3s
```

### Run the chaos scenario

```bash
./scripts/chaos/break-catalog.sh
```

While chaos is active, send requests to observe the circuit opening:

```bash
oc port-forward deployment/api-gateway 8080:8080 -n retailflow &
PF_PID=$!
sleep 2

for i in $(seq 1 15); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    http://localhost:8080/api/products)
  echo "Request $i: HTTP $STATUS"
  sleep 1
done

kill $PF_PID 2>/dev/null
```

**Expected output during chaos:**
```
Request 1: HTTP 503
Request 2: HTTP 503
Request 3: HTTP 503
Request 4: HTTP 503
...
```

**Expected output after chaos is disabled:**
```
Request 12: HTTP 200
Request 13: HTTP 200
Request 14: HTTP 200
```

### What to look for

- Requests return `503` immediately — Envoy is returning the error before the request reaches the catalog pod (the circuit is open)
- After the 30-second `baseEjectionTime`, the host is readmitted and requests return `200`
- In Kiali, the error rate spike and recovery are visible in the graph edge labels

To restore catalog manually without waiting:

```bash
./scripts/chaos/restore-catalog.sh
```

---

## Scenario 5 — AuthorizationPolicy: zero-trust between services

Estimated time: **10 minutes**

### What is this?

An AuthorizationPolicy is a firewall rule at the application layer. It uses the
mTLS peer identity (the ServiceAccount of the calling pod) to decide whether a
request is allowed — not an IP address, which can be spoofed, but a
cryptographically verified identity issued by Istio's CA.

### The problem it solves

CloudHop Travel processes real payments. By default, with mTLS enabled, any pod
in the mesh can call any other pod. If the `recommendations` service (a Python
microservice that reads mock data) is compromised through a dependency
vulnerability, an attacker could use it to POST requests directly to the
`payments` service and initiate fraudulent transactions. There is nothing in the
network that would stop it — both pods are in the same namespace.

An AuthorizationPolicy closes this gap: only the `orders` service — which holds
the `orders` ServiceAccount — is permitted to call `payments`. Any other caller
receives an immediate `403 RBAC: access denied`.

### How it works in CloudHop Travel

The policy selects pods with `app.kubernetes.io/name: payments` and defines a
single ALLOW rule:

- **From**: source principal `cluster.local/ns/retailflow/sa/orders`
  (the `orders` ServiceAccount, verified via mTLS certificate)
- **To**: HTTP methods `POST` and `GET`

This works because:
1. Each RetailFlow Deployment has a dedicated ServiceAccount (`orders`, `catalog`, etc.)
2. Istio's CA issues an X.509 certificate with a SPIFFE URI encoding the ServiceAccount
3. Envoy validates that URI before forwarding the request

> **Note:** The identity model used in this workshop — istiod acting as the
> internal CA issuing SPIFFE certificates to each ServiceAccount — is GA and
> production-supported in OSSM 3.x. Integration with SPIRE as an external CA
> (for organizations with an existing corporate PKI) is currently being tested
> and validated with OpenShift Service Mesh and is not yet GA.
> See the [OSSM 3.3 release notes](https://www.redhat.com/en/blog/openshift-service-mesh-33-adds-post-quantum-cryptography) for more details.

### What you will see in Kiali

- In the **Graph** view, the edge from `orders` → `payments` shows normal traffic
- If you generate a request from a different service (e.g. via `curl` from the catalog pod),
  Kiali shows a `403` error on that edge

### Apply

The policy is already applied. Verify:

```bash
oc get authorizationpolicy payments-allow-orders-only -n retailflow
```

### Verify

Test that `orders` can reach `payments` (authorized):

```bash
ORDERS_POD=$(oc get pod -n retailflow \
  -l app.kubernetes.io/name=orders \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')

oc exec "$ORDERS_POD" -c orders -n retailflow -- \
  curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://payments:8080/payments \
  -H "Content-Type: application/json" \
  -d '{"orderId":1,"amount":99.99}'
# Expected: 200 or 400 (request reaches payments, which validates the payload)
```

Test that `catalog` cannot reach `payments` (unauthorized):

```bash
CATALOG_POD=$(oc get pod -n retailflow \
  -l app.kubernetes.io/name=catalog \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')

oc exec "$CATALOG_POD" -c catalog -n retailflow -- \
  curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://payments:8080/payments \
  -H "Content-Type: application/json" \
  -d '{"orderId":1,"amount":99.99}'
# Expected: 403
```

### What to look for

- The `orders` → `payments` call returns `200` or `400` (the payments service received it)
- The `catalog` → `payments` call returns `403 RBAC: access denied` — Envoy rejected it
  at the sidecar before it reached the payments application
- In Kiali, the rejected call appears as a red `403` edge from `catalog` to `payments`

---

## Cleanup

To remove all mesh resources while keeping RetailFlow running:

```bash
# Remove traffic policies
oc delete -k workshops/01-service-mesh/deploy/base/03-traffic/

# Remove control plane and namespaces
oc delete -k workshops/01-service-mesh/deploy/base/01-control-plane/

# Remove namespace mesh labels
oc label namespace retailflow istio-injection- istio-discovery-

# Restart pods to remove sidecars
oc rollout restart deployment -n retailflow
```

To remove operators:

```bash
oc delete subscription sailoperator kiali-ossm -n openshift-operators
oc delete csv -l operators.coreos.com/sailoperator.openshift-operators \
  -n openshift-operators
oc delete csv -l operators.coreos.com/kiali-ossm.openshift-operators \
  -n openshift-operators
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Pods show `1/1` after rollout restart | Injection webhook not ready when pods scheduled | Wait for istiod: `oc wait --for=condition=Ready pod -l app=istiod -n istio-system --timeout=120s`, then re-roll |
| `no matches for kind "Istio"` on apply | Sail Operator CSV not yet Succeeded | Wait 2–3 min and re-apply: `oc apply -k ...` |
| `no matches for kind "Kiali"` on apply | Kiali Operator CSV not yet Succeeded | Same as above |
| Kiali graph is empty | No traffic has been generated | Run the port-forward traffic loop in Scenario 1 |
| No lock icons in Kiali | mTLS not enforced | Check PeerAuthentication: `oc get peerauthentication -n retailflow` |
| `403` on all payments calls | AuthorizationPolicy applied before mTLS was working | Verify sidecars are `2/2` and delete/recreate the AuthorizationPolicy |
| Database connections failing after mesh | mTLS applied to PostgreSQL port | Check the per-service port-level DISABLE policies: `oc get peerauthentication -n retailflow` |
| Gateway pod stays `0/1` | `istio-ingress` namespace not labelled for injection | Check: `oc get ns istio-ingress --show-labels` — must have `istio-injection=enabled` |
| `HTTPRoute` status not `Accepted` | Gateway API CRDs not installed | Sail Operator installs the CRDs; verify istiod is running first |
| `curl` to `cloudhop-mesh.apps-crc.testing` returns connection refused | Route not created or `cloudhop-gateway-istio` Service not yet provisioned | Check: `oc get svc -n istio-ingress` and `oc get route -n istio-ingress` |
