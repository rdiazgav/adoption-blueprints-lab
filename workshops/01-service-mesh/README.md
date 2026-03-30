# Workshop 01 — Service Mesh (OSSM 3.x / Sail Operator)

This workshop deploys OpenShift Service Mesh 3.x using the Sail Operator and Kiali
on top of the RetailFlow application. It demonstrates mTLS enforcement, traffic
splitting between payments v1/v2, and mesh observability via Kiali.

## Prerequisites

- RetailFlow deployed via `workshops/00-setup/` (namespace `retailflow` must exist)
- `cluster-admin` permissions
- OpenShift 4.14+ or CRC with >= 16 GB RAM

## What gets deployed

| Layer | Resources |
|---|---|
| Operators | Sail Operator (OSSM), Kiali Operator |
| Control plane | `istio-system`, `istio-cni`, `istio-ingress` namespaces; IstioCNI, Istio CR, Kiali CR |
| Gateway infra | ServiceAccount, Role, RoleBinding, Deployment, Service, Route in `istio-ingress` |
| Namespace config | Mesh labels on `retailflow` namespace |
| Traffic policy | PeerAuthentication (STRICT mTLS), DestinationRule + VirtualService for payments canary (90/10) |

## How to apply

### CRC (recommended for local development)

```bash
oc apply -k workshops/01-service-mesh/deploy/overlays/crc
```

### Wait for operators to be ready before applying control plane

Operator installation is asynchronous. After applying, wait for the CSVs:

```bash
oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -l operators.coreos.com/sailoperator.openshift-operators \
  -n openshift-operators --timeout=300s

oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -l operators.coreos.com/kiali-ossm.openshift-operators \
  -n openshift-operators --timeout=300s
```

### Verify the mesh

```bash
# Control plane
oc get istio default
oc get istiocni default
oc get kiali kiali -n istio-system

# Ingress gateway
oc get pods -n istio-ingress
oc get route istio-ingressgateway -n istio-ingress

# Sidecar injection in retailflow
oc get pods -n retailflow -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

The gateway is reachable at: `https://cloudhop-mesh.apps-crc.testing`
