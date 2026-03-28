# Adoption Blueprints Lab — project context for Claude Code

## What is this project?

A modular workshop platform built around a reference application called **RetailFlow**.
The goal is to demonstrate Red Hat OpenShift adoption across multiple technology areas
(service mesh, pipelines, GitOps, security, observability, etc.) using a realistic
application that participants can relate to.

Each workshop is self-contained and targets a specific Red Hat technology. The application
code never changes between workshops — only the platform layer on top of it does.

## Reference application: RetailFlow

A simplified e-commerce platform. Services:

| Service | Language | Description |
|---|---|---|
| `api-gateway` | Quarkus 3.8 JVM | Entry point, routing, auth token validation |
| `orders` | Quarkus 3.8 JVM | Order lifecycle (create, read, update status) |
| `catalog` | Quarkus 3.8 JVM | Product catalog (list, search, detail) |
| `payments` | Quarkus 3.8 JVM | Payment processing — two versions (v1, v2) for canary scenarios |
| `recommendations` | Python 3.11 / FastAPI | Product recommendations (mock data, no ML model) |
| `frontend` | Node.js / React | Customer-facing storefront |

All Quarkus services use:
- Quarkus 3.8 (JVM mode — not native, to keep build times short)
- RESTEasy Reactive for REST endpoints
- Hibernate ORM with Panache for persistence
- SmallRye Health for liveness and readiness probes at `/q/health/live` and `/q/health/ready`
- Micrometer with Prometheus registry for metrics
- OpenTelemetry for distributed tracing with W3C trace context propagation
- PostgreSQL as the database (except api-gateway and frontend)

The Python recommendations service uses:
- FastAPI
- `/health` endpoint for liveness
- Mock data — no real database or model

## Target environment

- **Primary**: Red Hat OpenShift Local (CRC) with 16 GB RAM, 6 CPUs, 100 GB disk
- **Secondary**: Any OpenShift 4.14+ cluster with cluster-admin permissions
- **Tooling**: Podman for local builds, Quay for image registry, Kustomize for manifests

## Repository structure

```
adoption-blueprints-lab/
├── apps/                        # RetailFlow source code
│   ├── api-gateway/
│   ├── orders/
│   ├── catalog/
│   ├── payments/
│   ├── recommendations/
│   └── frontend/
├── deploy/
│   ├── base/                    # Kustomize base — cluster-agnostic manifests
│   └── overlays/
│       ├── crc/                 # CRC overrides (minimal resources, emptyDir storage)
│       ├── demo-platform/       # Shared cluster overrides
│       └── production/
├── workshops/                   # One directory per workshop
│   ├── 00-setup/                # Base deployment — prerequisite for all workshops
│   ├── 01-service-mesh/         # OSSM 3.x, Gateway API, Kiali
│   ├── 02-observability/        # OpenTelemetry, Tempo, Loki, Prometheus, Grafana
│   ├── 03-pipelines/            # Tekton / OpenShift Pipelines
│   ├── 04-gitops/               # Argo CD / OpenShift GitOps
│   ├── 05-keycloak/             # Keycloak / RH SSO, OIDC, JWT
│   ├── 06-quay/                 # Quay registry, image scanning, mirroring
│   ├── 07-acs/                  # ACS / StackRox, runtime security, CVE policies
│   ├── 08-acm/                  # ACM, multi-cluster, governance policies
│   ├── 09-developer-hub/        # Red Hat Developer Hub, Backstage, golden paths
│   └── 10-openshift-ai/         # OpenShift AI, model serving
├── scripts/
│   └── smoke-test.sh            # Verifies all services are healthy
└── docs/
```

## Naming conventions

- Namespace: `retailflow`
- Image labels: `app.kubernetes.io/name`, `app.kubernetes.io/version`, `app.kubernetes.io/part-of: retailflow`
- All services expose metrics at `/q/metrics` (Quarkus) or `/metrics` (Python)
- Quarkus health: `/q/health/live` and `/q/health/ready`
- Python health: `/health`

## Manifests

- Use Kustomize (no Helm)
- `deploy/base/` contains cluster-agnostic Deployments, Services, and ConfigMaps
- `deploy/overlays/crc/` patches resource requests/limits down for CRC
- `deploy/overlays/crc/` uses `emptyDir` for storage (no PersistentVolumeClaims)
- Each workshop has its own `deploy/` directory with overlays for crc and demo-platform

## What to build next

The immediate priority is implementing the Quarkus services one by one, starting with `orders`.
Each service needs: source code, Dockerfile, and base Kustomize manifests.
