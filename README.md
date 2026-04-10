# Adoption Blueprints Lab

## 📖 Documentation

The full workshop guides are available at:
**https://rdiazgav.github.io/adoption-blueprints-lab/adoption-blueprints-lab/main/index.html**

---

A hands-on, modular lab platform built on top of a realistic reference application — **RetailFlow** — designed to demonstrate Red Hat OpenShift adoption across multiple technology areas.

Each workshop is self-contained and can be taken independently or as part of a full adoption journey.

---

## What is this?

Most demo applications are either too simple to be credible or too complex to be useful in a workshop. **Adoption Blueprints Lab** tries to find the middle ground: a real microservices application built with Red Hat technologies, structured so that each layer of the platform can be introduced progressively and in isolation.

The reference application — RetailFlow — is a simplified e-commerce platform with services written in Quarkus, Python and Node.js. The application itself never changes between workshops. What changes is which platform capability you activate on top of it.

---

## Reference application: RetailFlow

RetailFlow simulates a retail platform with the following services:

| Service | Technology | Role |
|---|---|---|
| `frontend` | Node.js / React | Customer-facing UI |
| `api-gateway` | Quarkus | Entry point, routing, auth enforcement |
| `orders` | Quarkus | Order lifecycle management |
| `catalog` | Quarkus | Product catalog |
| `payments` | Quarkus | Payment processing (v1 and v2 for canary scenarios) |
| `recommendations` | Python / FastAPI | Product recommendations |

---

## Workshops

Each workshop targets a specific Red Hat technology area. They share the same base application and the same cluster, so capabilities compound as you progress.

| # | Workshop | Key technologies |
|---|---|---|
| [00](./workshops/00-setup/README.md) | Platform setup | OpenShift, CRC, RetailFlow base deployment |
| [01](./workshops/01-service-mesh/README.md) | Service mesh | OSSM 3.x, Istio, Kiali, Gateway API |
| [02](./workshops/02-observability/README.md) | Observability | OpenTelemetry, Tempo, Loki, Prometheus, Grafana |
| [03](./workshops/03-pipelines/README.md) | Pipelines | Tekton, OpenShift Pipelines |
| [04](./workshops/04-gitops/README.md) | GitOps | Argo CD, OpenShift GitOps |
| [05](./workshops/05-keycloak/README.md) | Identity & access | Keycloak, OIDC, JWT |
| [06](./workshops/06-quay/README.md) | Image registry | Quay, image scanning, mirroring |
| [07](./workshops/07-acs/README.md) | Security | ACS / StackRox, runtime policies, CVE scanning |
| [08](./workshops/08-acm/README.md) | Multi-cluster | ACM, cluster policies, application distribution |
| [09](./workshops/09-developer-hub/README.md) | Developer platform | Red Hat Developer Hub, Backstage, golden paths |
| [10](./workshops/10-openshift-ai/README.md) | AI / ML | OpenShift AI, model serving, recommendations model |

---

## How to use this lab

### Option A — Single workshop

Each workshop is self-contained. Start with **workshop 00** to deploy the base application, then jump directly to the workshop you need.

```
00-setup → [any workshop]
```

### Option B — Curated path

Some workshops are more meaningful in combination. Recommended paths:

**Platform engineering track**
```
00 → 03 (Pipelines) → 04 (GitOps) → 06 (Quay) → 08 (ACM)
```

**Security track**
```
00 → 06 (Quay) → 07 (ACS) → 05 (Keycloak) → 01 (Service Mesh)
```

**Developer experience track**
```
00 → 03 (Pipelines) → 04 (GitOps) → 05 (Keycloak) → 09 (Developer Hub)
```

### Option C — Full adoption journey

All workshops in order. At the end you have a fully instrumented platform running RetailFlow with pipelines, GitOps, observability, security scanning, identity management and service mesh — all integrated.

---

## Cluster requirements

### Local development (CRC)

[Red Hat OpenShift Local](https://developers.redhat.com/products/openshift-local/overview) is the recommended environment for individual use and workshop preparation.

Minimum CRC configuration:

```bash
crc config set memory 16384
crc config set cpus 6
crc config set disk-size 100
crc start
```

### Shared environments (Demo Platform / RHDP)

For guided workshops with customers, the lab is designed to run on any OpenShift 4.14+ cluster meeting the following requirements:

- 3 worker nodes, 8 vCPU / 16 GB RAM each
- StorageClass with RWO support available
- Operator Lifecycle Manager (OLM) enabled
- Access to Red Hat operator catalog
- Ability to create projects and install operators

---

## Repository structure

```
adoption-blueprints-lab/
├── apps/                        # RetailFlow source code
│   ├── api-gateway/             #   Quarkus
│   ├── orders/                  #   Quarkus
│   ├── catalog/                 #   Quarkus
│   ├── payments/                #   Quarkus (v1 and v2)
│   ├── recommendations/         #   Python / FastAPI
│   └── frontend/                #   Node.js / React
├── deploy/
│   ├── base/                    # Kustomize base manifests
│   └── overlays/
│       ├── crc/                 # CRC-specific overrides
│       ├── demo-platform/       # Shared cluster overrides
│       └── production/          # Production-grade overrides
├── workshops/                   # One directory per workshop
│   └── XX-name/
│       ├── README.md            #   Workshop guide
│       ├── scenarios/           #   Step-by-step scenario guides
│       └── deploy/              #   Workshop-specific manifests
│           └── overlays/
│               ├── crc/
│               └── demo-platform/
├── scripts/                     # Helper scripts
└── docs/                        # Architecture and design docs
```

---

## Prerequisites

- `oc` CLI — [installation guide](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)
- `kubectl` CLI
- `podman` or `docker` — for local image builds
- Access to [quay.io](https://quay.io) or an internal registry

---

## Contributing

This is currently a personal project. Contributions and feedback are welcome once the base workshops are stable. See [docs/contributing.md](./docs/contributing.md) for guidelines.

---

## License

Apache License 2.0 — see [LICENSE](./LICENSE) for details.
