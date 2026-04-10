#!/bin/bash
set -euo pipefail

# Usage: ./run-pipeline.sh <service-name> [git-revision]
SERVICE_NAME="${1:-}"
GIT_REVISION="${2:-latest}"

if [[ -z "$SERVICE_NAME" ]]; then
  echo "Usage: $0 <service-name> [git-revision]"
  echo "  service-name: api-gateway | orders | catalog | payments | recommendations | frontend"
  exit 1
fi

NAMESPACE=${NAMESPACE:-retailflow}
GIT_URL=${GIT_URL:-https://github.com/rdiazgav/adoption-blueprints-lab.git}

# Quarkus services require Maven build
QUARKUS_SERVICES=("api-gateway" "orders" "catalog" "payments")
GENERIC_SERVICES=("recommendations" "frontend")

is_quarkus() {
  for s in "${QUARKUS_SERVICES[@]}"; do
    [[ "$s" == "$1" ]] && return 0
  done
  return 1
}

if is_quarkus "$SERVICE_NAME"; then
  PIPELINE="quarkus-service-pipeline"
  WORKSPACE_MAVEN='- name: maven-cache
      persistentVolumeClaim:
        claimName: pipeline-maven-cache-pvc'
else
  PIPELINE="generic-service-pipeline"
  WORKSPACE_MAVEN=""
fi

RUN_NAME=$(oc create -f - <<EOF | awk '{print $1}' | sed 's|pipelinerun.tekton.dev/||'
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ${SERVICE_NAME}-run-
  namespace: ${NAMESPACE}
spec:
  pipelineRef:
    name: ${PIPELINE}
  serviceAccountName: pipeline-sa
  timeouts:
    pipeline: 30m
  workspaces:
    - name: source
      persistentVolumeClaim:
        claimName: pipeline-source-pvc
    - name: docker-credentials
      secret:
        secretName: quay-credentials
$(echo "$WORKSPACE_MAVEN" | sed 's/^/    /')
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

echo "==> PipelineRun created: $RUN_NAME"
echo "    Following logs (Ctrl+C to detach, pipeline continues running)..."
tkn pipelinerun logs -f "$RUN_NAME" -n "$NAMESPACE"
