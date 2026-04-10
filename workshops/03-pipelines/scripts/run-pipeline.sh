#!/bin/bash
set -euo pipefail

# Usage: ./run-pipeline.sh <service-name> [git-revision]
SERVICE_NAME="${1:-}"
GIT_REVISION="${2:-master}"

if [[ -z "$SERVICE_NAME" ]]; then
  echo "Usage: $0 <service-name> [git-revision]"
  echo "  service-name: api-gateway | orders | catalog | payments | recommendations | frontend"
  exit 1
fi

NAMESPACE=${NAMESPACE:-retailflow}
GIT_URL=${GIT_URL:-https://github.com/rdiazgav/adoption-blueprints-lab.git}

# Quarkus services require Maven build
QUARKUS_SERVICES=("api-gateway" "orders" "catalog" "payments")

is_quarkus() {
  for s in "${QUARKUS_SERVICES[@]}"; do
    [[ "$s" == "$1" ]] && return 0
  done
  return 1
}

if is_quarkus "$SERVICE_NAME"; then
  RUN_NAME=$(oc create -f - <<EOF | awk '{print $1}' | sed 's|pipelinerun.tekton.dev/||'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${SERVICE_NAME}-run-
  namespace: ${NAMESPACE}
spec:
  pipelineRef:
    name: quarkus-service-pipeline
  serviceAccountName: pipeline-sa
  timeouts:
    pipeline: 30m
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
    - name: docker-credentials
      secret:
        secretName: quay-credentials
    - name: maven-cache
      persistentVolumeClaim:
        claimName: pipeline-maven-cache-pvc
  params:
    - name: GIT_URL
      value: "${GIT_URL}"
    - name: GIT_REVISION
      value: "${GIT_REVISION}"
    - name: SERVICE_NAME
      value: "${SERVICE_NAME}"
    - name: SERVICE_DIR
      value: "apps/${SERVICE_NAME}"
    - name: IMAGE_TAG
      value: "${GIT_REVISION}"
EOF
)
else
  RUN_NAME=$(oc create -f - <<EOF | awk '{print $1}' | sed 's|pipelinerun.tekton.dev/||'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${SERVICE_NAME}-run-
  namespace: ${NAMESPACE}
spec:
  pipelineRef:
    name: generic-service-pipeline
  serviceAccountName: pipeline-sa
  timeouts:
    pipeline: 30m
  workspaces:
    - name: source
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
    - name: docker-credentials
      secret:
        secretName: quay-credentials
  params:
    - name: GIT_URL
      value: "${GIT_URL}"
    - name: GIT_REVISION
      value: "${GIT_REVISION}"
    - name: SERVICE_NAME
      value: "${SERVICE_NAME}"
    - name: SERVICE_DIR
      value: "apps/${SERVICE_NAME}"
    - name: IMAGE_TAG
      value: "${GIT_REVISION}"
EOF
)
fi

echo "==> PipelineRun created: $RUN_NAME"
echo "    Following logs (Ctrl+C to detach, pipeline continues running)..."
tkn pipelinerun logs -f "$RUN_NAME" -n "$NAMESPACE"
