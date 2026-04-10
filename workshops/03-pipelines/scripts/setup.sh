#!/bin/bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-retailflow}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/../deploy/base"

echo "==> [0/5] (Optional) Create Quay repositories..."
read -r -p "    Do you want to create Quay repos now? [y/N] " CREATE_REPOS
if [[ "${CREATE_REPOS,,}" == "y" ]]; then
  if [[ -z "${QUAY_USER:-}" || -z "${QUAY_TOKEN:-}" ]]; then
    echo "    QUAY_USER and QUAY_TOKEN must be set to create repos."
    echo "    Skipping. Run scripts/create-quay-repos.sh manually when ready."
  else
    bash "$SCRIPT_DIR/create-quay-repos.sh"
  fi
else
  echo "    Skipping. Run scripts/create-quay-repos.sh manually when ready."
fi

echo "==> [1/5] Installing OpenShift Pipelines operator..."
oc apply -f "$BASE_DIR/00-operators/subscription.yaml"

echo "    Waiting for OpenShift Pipelines CSV to succeed (up to 5 min)..."
for i in $(seq 1 30); do
  PHASE=$(oc get csv -n openshift-operators \
    --no-headers 2>/dev/null | grep pipelines | awk '{print $NF}' || true)
  if [[ "$PHASE" == "Succeeded" ]]; then
    echo "    CSV ready."
    break
  fi
  echo "    ($i/30) CSV phase: ${PHASE:-pending}..."
  sleep 10
done
if [[ "$PHASE" != "Succeeded" ]]; then
  echo "ERROR: Pipelines operator did not reach Succeeded after 5 min" >&2
  exit 1
fi

echo "==> [2/5] Installing community Tasks from Tekton Hub..."
oc apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/git-clone/0.9/raw -n "$NAMESPACE"
oc apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/buildah/0.6/raw -n "$NAMESPACE"

echo "==> [3/5] Applying RBAC..."
oc apply -k "$BASE_DIR/01-rbac"

echo "    Linking quay-credentials secret to pipeline-sa (if secret exists)..."
if oc get secret quay-credentials -n "$NAMESPACE" &>/dev/null; then
  oc secret link pipeline-sa quay-credentials --for=pull,mount -n "$NAMESPACE"
  echo "    Secret linked."
else
  echo "    WARNING: quay-credentials secret not found — run 'oc apply -f quay-credentials.yaml' and relink manually"
fi

echo "==> [4/5] Applying workspaces (PVCs)..."
oc apply -k "$BASE_DIR/02-workspaces"

echo "==> [5/5] Applying custom Tasks and Pipelines..."
oc apply -k "$BASE_DIR/03-tasks"
oc apply -k "$BASE_DIR/04-pipelines"

echo ""
echo "✓ Setup complete."
echo ""
echo "Next steps:"
echo "  1. If quay-credentials was not found above, apply it now and re-run setup to link automatically:"
echo "       cp $BASE_DIR/01-rbac/quay-credentials.yaml.template quay-credentials.yaml"
echo "       # Edit quay-credentials.yaml — add your base64-encoded docker config"
echo "       oc apply -f quay-credentials.yaml -n $NAMESPACE"
echo "       bash $SCRIPT_DIR/setup.sh   # step [3/5] will link the secret"
echo ""
echo "  2. Run a pipeline:"
echo "       $SCRIPT_DIR/run-pipeline.sh catalog"
