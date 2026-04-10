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

## Build process per service

Each service has a different build process depending on the stack:

### Quarkus services (api-gateway, orders, catalog, payments)
1. Compile locally with Maven wrapper:
   `./mvnw package -DskipTests`
2. Build container image with Podman (single-stage, copies pre-built jar):
   `podman build --no-cache -t quay.io/rdiazgav/retailflow-<service>:<tag> .`
3. Push to registry:
   `podman push quay.io/rdiazgav/retailflow-<service>:<tag>`

The Dockerfile copies from `target/quarkus-app/` — the jar must be compiled
before building the image.

### Python service (recommendations)
1. No local compilation needed
2. Build container image with Podman (pip install runs inside Dockerfile):
   `podman build --no-cache -t quay.io/rdiazgav/retailflow-recommendations:<tag> .`
3. Push to registry

### Node.js service (frontend)
1. No local compilation needed
2. Build container image with Podman (npm install runs inside Dockerfile):
   `podman build --no-cache -t quay.io/rdiazgav/retailflow-frontend:<tag> .`
3. Push to registry

## Image registry

All images are hosted on quay.io under the rdiazgav organization:
- `quay.io/rdiazgav/retailflow-api-gateway`
- `quay.io/rdiazgav/retailflow-orders`
- `quay.io/rdiazgav/retailflow-catalog`
- `quay.io/rdiazgav/retailflow-payments`
- `quay.io/rdiazgav/retailflow-recommendations`
- `quay.io/rdiazgav/retailflow-frontend`

## Current image tags (latest working versions)

- api-gateway: 1.0.2
- orders: 1.0.0
- catalog: 1.1.0
- payments: 1.0.0
- recommendations: 1.0.1 (UBI9-based; ~1.17 GB is expected — intentional for OpenShift/ACS compatibility)
- frontend: 1.0.5

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

## Documentation

### README ↔ Antora sync rule

Whenever a workshop README.md is created or updated, the corresponding Antora
pages under `docs/modules/ROOT/pages/<workshop-dir>/` must be updated in the
same commit to stay in sync.

Mapping covers all workshops, present and future:
- `workshops/00-setup/README.md`         → `docs/.../00-setup/`
- `workshops/01-service-mesh/README.md`  → `docs/.../01-service-mesh/`
- `workshops/02-observability/README.md` → `docs/.../02-observability/`
- `workshops/03-pipelines/README.md`     → `docs/.../03-pipelines/`
- `workshops/04-gitops/README.md`        → `docs/.../04-gitops/`
- `workshops/05-keycloak/README.md`      → `docs/.../05-keycloak/`
- `workshops/06-quay/README.md`          → `docs/.../06-quay/`
- `workshops/07-acs/README.md`           → `docs/.../07-acs/`
- `workshops/08-acm/README.md`           → `docs/.../08-acm/`
- `workshops/09-developer-hub/README.md` → `docs/.../09-developer-hub/`
- `workshops/10-openshift-ai/README.md`  → `docs/.../10-openshift-ai/`

When a new workshop is added, extend this mapping accordingly.

Specifically:
- New sections in README → new content in the relevant `.adoc` page
- New scripts or commands → added to the appropriate `.adoc` step with
  `[source,bash]` block and verification output
- New files in `deploy/` → reflected in the repository layout in `index.adoc`

This rule applies to all future workshops.

## What to build next

The immediate priority is implementing the Quarkus services one by one, starting with `orders`.
Each service needs: source code, Dockerfile, and base Kustomize manifests.
