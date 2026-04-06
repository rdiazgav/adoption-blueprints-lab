# Workshop 01 — Service Mesh (OSSM 3.x / Sail Operator)

This workshop deploys OpenShift Service Mesh 3.x using the Sail Operator and Kiali
on top of the RetailFlow application. It demonstrates mTLS enforcement, traffic
splitting between payments v1/v2, and mesh observability via Kiali.

Estimated time: **45–60 minutes**

---

## Prerequisites

- RetailFlow deployed and healthy via `workshops/00-setup/`
- `cluster-admin` permissions
- OpenShift 4.14+ or CRC with >= 16 GB RAM

---

## What gets deployed

| Layer | Resources |
|---|---|
| Operators | Sail Operator (OSSM), Kiali Operator |
| Control plane | `istio-system`, `istio-cni`, `istio-ingress` namespaces; IstioCNI, Istio CR, Kiali CR |
| Gateway infra | ServiceAccount, Role, RoleBinding, Deployment, Service, Route in `istio-ingress` |
| Namespace config | Mesh labels on `retailflow` namespace (enables sidecar injection) |
| Traffic policy | PeerAuthentication (STRICT mTLS), DestinationRule + VirtualService for payments canary (90/10) |

---

## Step 1 — Apply the mesh manifests

```bash
oc apply -k workshops/01-service-mesh/deploy/overlays/crc
```

**Expected output:**
```
namespace/istio-system created
namespace/istio-cni created
namespace/istio-ingress created
namespace/retailflow configured
operatorgroup.operators.coreos.com/global-operators configured
subscription.operators.coreos.com/sailoperator created
subscription.operators.coreos.com/kiali-ossm created
istiocni.sailoperator.io/default created
istio.sailoperator.io/default created
kiali.kiali.io/kiali created
serviceaccount/cloudhop-gateway-sa created
role.rbac.authorization.k8s.io/istio-ingressgateway-sds created
rolebinding.rbac.authorization.k8s.io/istio-ingressgateway-sds created
deployment.apps/istio-ingressgateway created
service/istio-ingressgateway created
route.route.openshift.io/istio-ingressgateway created
peerauthentication.security.istio.io/default created
peerauthentication.security.istio.io/frontend-permissive created
destinationrule.networking.istio.io/payments created
virtualservice.networking.istio.io/payments created
destinationrule.networking.istio.io/catalog created
virtualservice.networking.istio.io/catalog created
```

**What to look for:**
- All resources show `created` or `configured` — not `error`
- The `retailflow` namespace shows `configured` (it already existed, now has mesh labels)
- If any Istio or Kiali CRs fail with `no matches for kind`, the operator has not finished installing — wait and re-apply

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `no matches for kind "Istio"` | Sail Operator CSV not yet Succeeded | Wait 2–3 minutes and re-run `oc apply -k` |
| `no matches for kind "Kiali"` | Kiali Operator CSV not yet Succeeded | Same as above |
| `namespace "retailflow" not found` | Workshop 00 not completed | Run Workshop 00 first |

---

## Step 2 — Wait for operators to be ready

Operator installation is asynchronous. Monitor progress:

```bash
oc get csv -n openshift-operators -w
```

**Expected output** (after 2–4 minutes):
```
NAME                      DISPLAY                    VERSION   REPLACES   PHASE
sailoperator.v1.0.0       Sail Operator              1.0.0                Succeeded
kiali-operator.v2.4.0     Kiali Operator             2.4.0                Succeeded
```

**What to look for:**
- `PHASE` must be `Succeeded` for both operators before proceeding
- `Installing` is normal for the first 1–3 minutes
- `Failed` means there was a problem fetching the operator bundle — check connectivity to `registry.redhat.io`

Wait for both CSVs to reach Succeeded:

```bash
oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -l operators.coreos.com/sailoperator.openshift-operators \
  -n openshift-operators --timeout=300s

oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -l operators.coreos.com/kiali-ossm.openshift-operators \
  -n openshift-operators --timeout=300s
```

**Expected output:**
```
clusterserviceversion.operators.coreos.com/sailoperator.v1.0.0 condition met
clusterserviceversion.operators.coreos.com/kiali-operator.v2.4.0 condition met
```

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `timed out waiting for the condition` | Operator install stalled | Check `oc get events -n openshift-operators` for pull errors |
| CSV stuck in `Installing` | Operator pod crash | Check: `oc get pods -n openshift-operators` and look for `CrashLoopBackOff` |
| `error: label selector ... found no objects` | Subscription not created | Re-apply: `oc apply -k workshops/01-service-mesh/deploy/overlays/crc` |

---

## Step 3 — Verify the control plane

Check the Istio control plane status:

```bash
oc get istio default
```

**Expected output:**
```
NAME      REVISIONS   READY   IN USE   ACTIVE REVISION   STATUS    AGE
default   1           1       1        default-v1-24-3   Healthy   8m
```

**What to look for:**
- `STATUS` is `Healthy`
- `READY` equals `REVISIONS` — if it shows `0/1`, istiod is still starting

Check IstioCNI:

```bash
oc get istiocni default
```

**Expected output:**
```
NAME      READY   STATUS    AGE
default   True    Healthy   8m
```

Check the Kiali CR:

```bash
oc get kiali kiali -n istio-system
```

**Expected output:**
```
NAME    AGE
kiali   6m
```

Verify the control plane pods are running:

```bash
oc get pods -n istio-system
```

**Expected output:**
```
NAME                      READY   STATUS    RESTARTS   AGE
istiod-default-xxx-yyyyy   1/1     Running   0          8m
```

**What to look for:**
- `istiod-default-xxx-yyyyy` is `1/1 Running` — this is the Pilot/istiod pod that manages the mesh
- The Kiali pod appears here once the Kiali CR is reconciled (may take an extra 2–3 minutes)

Check istiod is fully ready:

```bash
oc wait --for=condition=Ready pod -l app=istiod -n istio-system --timeout=180s
```

**Expected output:**
```
pod/istiod-default-7c9b8d6f5-m4rvt condition met
```

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `STATUS: Reconciling` for minutes | Operator waiting for IstioCNI | Verify IstioCNI is Healthy first |
| istiod pod in `Pending` | Insufficient cluster resources | Check node allocatable: `oc describe node` |
| `STATUS: Error` on Istio CR | Configuration validation failure | Check: `oc describe istio default` for the error message |

---

## Step 4 — Verify the ingress gateway

```bash
oc get pods -n istio-ingress
```

**Expected output:**
```
NAME                                    READY   STATUS    RESTARTS   AGE
istio-ingressgateway-6d8f7c9b4-p3wkn   1/1     Running   0          7m
```

**What to look for:**
- `1/1 Running` — the `1/1` shows the injected Envoy sidecar is the container (gateway injection replaces the app container with the proxy)

```bash
oc get route istio-ingressgateway -n istio-ingress
```

**Expected output:**
```
NAME                   HOST/PORT                          PATH   SERVICES               PORT    TERMINATION   WILDCARD
istio-ingressgateway   cloudhop-mesh.apps-crc.testing            istio-ingressgateway   http2   edge          None
```

**What to look for:**
- `HOST/PORT` matches `cloudhop-mesh.apps-crc.testing`
- `TERMINATION` is `edge` — TLS is terminated at the OpenShift router; the gateway receives plain HTTP

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| Gateway pod stays `0/1` | Sidecar injection not triggered | Verify `istio-ingress` namespace has no injection label conflicts; restart the pod |
| Pod in `CrashLoopBackOff` | RBAC missing for SDS | Verify the Role and RoleBinding from `gateway-infra.yaml` were applied |

---

## Step 5 — Verify namespace labels and sidecar injection

Check that the retailflow namespace has the mesh labels:

```bash
oc get namespace retailflow --show-labels
```

**Expected output:**
```
NAME         STATUS   AGE   LABELS
retailflow   Active   45m   istio-discovery=enabled,istio-injection=enabled,kubernetes.io/metadata.name=retailflow
```

**What to look for:**
- Both `istio-injection=enabled` and `istio-discovery=enabled` must be present
- `istio-injection=enabled` triggers automatic sidecar injection on new pods
- `istio-discovery=enabled` matches the `discoverySelectors` in the Istio CR so istiod watches this namespace

Restart the retailflow pods to trigger sidecar injection:

```bash
oc rollout restart deployment -n retailflow
```

Wait for rollout to complete:

```bash
oc rollout status deployment/api-gateway -n retailflow
oc rollout status deployment/catalog -n retailflow
oc rollout status deployment/orders -n retailflow
oc rollout status deployment/payments-v1 -n retailflow
oc rollout status deployment/payments-v2 -n retailflow
oc rollout status deployment/recommendations -n retailflow
oc rollout status deployment/frontend -n retailflow
```

**Expected output** (for each):
```
deployment "api-gateway" successfully rolled out
```

Verify all pods now have 2 containers (app + Envoy sidecar):

```bash
oc get pods -n retailflow
```

**Expected output:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
api-gateway-7d9f8b6c4-xk2pn           2/2     Running   0          2m
catalog-6c8d9f7b5-m9rvt               2/2     Running   0          2m
frontend-5b7c6d8f9-p4wzq              2/2     Running   0          2m
orders-8f6b5c7d4-t7jkn                2/2     Running   0          2m
payments-v1-9d7c8b6f5-h3mnp           2/2     Running   0          2m
payments-v2-4f8c7d9b6-r6lqx           2/2     Running   0          2m
postgresql-catalog-7b9c8d6f5-w2vks    1/1     Running   0          45m
postgresql-orders-6d8f7c9b4-n8ptr     1/1     Running   0          45m
postgresql-payments-5c9b8d7f6-k5wjm   1/1     Running   0          45m
recommendations-8c6d7f9b5-q9xtn       2/2     Running   0          2m
redis-7f9c8b6d5-v4zrp                 1/1     Running   0          45m
```

**What to look for:**
- Application pods show `2/2` — the second container is the Envoy proxy (`istio-proxy`)
- PostgreSQL and Redis show `1/1` — these were excluded from injection intentionally (no mesh label on the pod template)
- Any pod still showing `1/1` after the rollout did not get the sidecar — check the namespace labels were applied before the rollout

Confirm container names:

```bash
oc get pods -n retailflow -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

**Expected output:**
```
api-gateway-7d9f8b6c4-xk2pn           api-gateway istio-proxy
catalog-6c8d9f7b5-m9rvt               catalog istio-proxy
frontend-5b7c6d8f9-p4wzq              frontend istio-proxy
orders-8f6b5c7d4-t7jkn                orders istio-proxy
payments-v1-9d7c8b6f5-h3mnp           payments istio-proxy
payments-v2-4f8c7d9b6-r6lqx           payments istio-proxy
postgresql-catalog-7b9c8d6f5-w2vks    postgresql
postgresql-orders-6d8f7c9b4-n8ptr     postgresql
postgresql-payments-5c9b8d7f6-k5wjm   postgresql
recommendations-8c6d7f9b5-q9xtn       recommendations istio-proxy
redis-7f9c8b6d5-v4zrp                 redis
```

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| Pod shows `1/1` after rollout | Injection webhook not ready when pod was scheduled | Wait for istiod to be healthy, then re-roll: `oc rollout restart deployment/<name> -n retailflow` |
| Pod stuck in `Init:0/1` after restart | Envoy proxy waiting for xDS config | Usually resolves in 30–60 seconds; if not, check istiod logs |

---

## Step 6 — Verify traffic policies

Check the PeerAuthentication resources:

```bash
oc get peerauthentication -n retailflow
```

**Expected output:**
```
NAME                  MODE         AGE
default               STRICT       10m
frontend-permissive   PERMISSIVE   10m
```

**What to look for:**
- `default` in STRICT mode means all pod-to-pod traffic in `retailflow` requires mTLS
- `frontend-permissive` overrides STRICT for the frontend pod, allowing the OpenShift router to connect over plain HTTP (edge TLS termination)

Check the DestinationRules:

```bash
oc get destinationrule -n retailflow
```

**Expected output:**
```
NAME       HOST       AGE
catalog    catalog    10m
payments   payments   10m
```

Check the VirtualServices:

```bash
oc get virtualservice -n retailflow
```

**Expected output:**
```
NAME       GATEWAYS   HOSTS        AGE
catalog               ["catalog"]  10m
payments              ["payments"] 10m
```

**What to look for:**
- Both DestinationRules and VirtualServices exist for `payments` (canary split) and `catalog` (circuit breaker + retry)
- `GATEWAYS` column is empty — these are internal mesh policies, not exposed via the ingress gateway

---

## Step 7 — Open Kiali

Get the Kiali route:

```bash
oc get route kiali -n istio-system -o jsonpath='{.spec.host}'
```

**Expected output:**
```
kiali-istio-system.apps-crc.testing
```

Open `https://kiali-istio-system.apps-crc.testing` in your browser and log in with your OpenShift credentials.

**What to look for in the Kiali Graph:**

1. Navigate to **Graph** and select namespace `retailflow`
2. Set the traffic source to **Last 1m** and enable **Traffic Animation**
3. Generate traffic first:

```bash
oc port-forward deployment/api-gateway 8080:8080 -n retailflow &
for i in $(seq 1 20); do
  curl -s http://localhost:8080/api/products > /dev/null
  curl -s http://localhost:8080/api/orders > /dev/null
done
```

**What you should see in Kiali:**
- All services appear as nodes connected by edges
- Edges show request rates (RPS) and success percentages
- Lock icons on edges indicate mTLS is active between services
- The `payments` service shows two versions (`v1`, `v2`) with weighted traffic

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| Kiali graph is empty | No traffic has flowed yet | Generate traffic with the port-forward loop above |
| Services appear but no lock icons | mTLS not active | Verify sidecars are injected (`2/2` pods) and PeerAuthentication is STRICT |
| Kiali login fails | OpenShift OAuth not configured | Verify `spec.auth.strategy: openshift` in the Kiali CR |

---

## Scenario A — Canary traffic split (payments v1/v2)

The VirtualService routes 90% of payments traffic to v1 and 10% to v2.

Generate traffic and observe the split:

```bash
oc port-forward deployment/api-gateway 8080:8080 -n retailflow &
PF_PID=$!
sleep 2

for i in $(seq 1 50); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST http://localhost:8080/api/payments \
    -H "Content-Type: application/json" \
    -d '{"orderId":1,"amount":99.99,"currency":"USD"}'
done

kill $PF_PID 2>/dev/null
```

**Expected output** (50 requests, approximately 45 to v1 and 5 to v2):
```
200
200
200
200
200
...
```

Verify the split in Kiali:

**What you should see:**
- In the Graph view, the `payments` node expands into `payments v1` and `payments v2`
- The edge labels show approximate request counts: ~90% to v1, ~10% to v2
- Both versions show green (healthy) status

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| All traffic goes to one version | DestinationRule subset labels don't match pod labels | Verify pod labels: `oc get pods -n retailflow -l app.kubernetes.io/name=payments --show-labels` |
| `503 No healthy upstream` | VirtualService references a subset with no matching pods | Check subset labels in `payments-destination-rule.yaml` match `app.kubernetes.io/version: v1` |

---

## Scenario B — Circuit breaker (catalog)

This scenario uses the chaos endpoint to make catalog return 503s, triggering Envoy's outlier detection.

**Step 1 — Run the chaos script:**

```bash
./scripts/chaos/break-catalog.sh
```

**Expected output:**
```
==> Starting port-forward to api-gateway...
==> Enabling chaos mode on catalog via http://localhost:8080/api/products/chaos/enable ...
{"chaos":"enabled"}

==> Catalog is now returning 503 on all product endpoints.
    Envoy will record consecutive 5xx errors and eject the host after 3 failures.

    Open Kiali and navigate to Graph > retailflow to watch the circuit open.
    Kiali URL:
      https://kiali-istio-system.apps-crc.testing

==> Watching pods for 30 seconds (Ctrl-C to skip)...
NAME                                  READY   STATUS    RESTARTS   AGE
...

==> Disabling chaos mode on catalog via http://localhost:8080/api/products/chaos/disable ...
{"chaos":"disabled"}

==> Chaos disabled. Watch Kiali to see the circuit close as catalog recovers.
```

**What to look for:**

During the 30-second chaos window, make requests to catalog:

```bash
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "products: %{http_code}\n" \
    http://localhost:8080/api/products
  sleep 1
done
```

**Expected output during chaos:**
```
products: 503
products: 503
products: 503
products: 503
products: 503
...
```

**What you should see in Kiali during chaos:**
- The `catalog` service node turns red or orange
- Edges to catalog show a high error rate percentage
- After 3 consecutive errors, the outlier detection ejects the catalog host — subsequent calls may return `503 No healthy upstream` from Envoy itself
- The `catalog` service shows a circuit-open indicator in the sidebar

**After chaos is disabled:**
```
products: 200
products: 200
products: 200
```

**What you should see in Kiali after recovery:**
- The `catalog` node returns to green
- Error rate drops to 0%
- Traffic resumes normally — the ejected host is re-admitted after `baseEjectionTime: 30s`

**Common issues:**
| Symptom | Cause | Fix |
|---|---|---|
| `{"chaos":"enabled"}` but requests still return 200 | Port-forward not pointing to correct pod | Kill and restart: `kill $PF_PID && oc port-forward deployment/api-gateway 8080:8080 -n retailflow &` |
| Circuit never opens in Kiali | Not enough requests to trigger outlier detection | Send more requests — outlier detection requires `consecutiveGatewayErrors: 3` |
| After recovery, still getting 503 | Ejection period not expired | Wait 30 seconds (the configured `baseEjectionTime`) and retry |
