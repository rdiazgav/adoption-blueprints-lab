#!/bin/bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-retailflow}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/../deploy/base"

echo "==> [1/5] Installing OpenShift Pipelines operator..."
oc apply -f "$BASE_DIR/00-operators/subscription.yaml"

echo "    Waiting for OpenShift Pipelines CSV to succeed (up to 5 min)..."
oc wait --for=jsonpath='{.status.phase}'=Succeeded \
  csv -l operators.coreos.com/openshift-pipelines-operator-rh.openshift-operators \
  -n openshift-operators --timeout=300s

echo "==> [2/5] Installing community Tasks from Tekton Hub..."
oc apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml -n "$NAMESPACE"
oc apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/buildah/0.6/buildah.yaml -n "$NAMESPACE"

echo "==> [3/5] Applying RBAC..."
oc apply -k "$BASE_DIR/01-rbac"

echo "==> [4/5] Applying workspaces (PVCs)..."
oc apply -k "$BASE_DIR/02-workspaces"

echo "==> [5/5] Applying custom Tasks and Pipelines..."
oc apply -k "$BASE_DIR/03-tasks"
oc apply -k "$BASE_DIR/04-pipelines"

echo ""
echo "✓ Setup complete."
echo ""
echo "Next steps:"
echo "  1. Create and apply Quay credentials:"
echo "       cp $BASE_DIR/01-rbac/quay-credentials.yaml.template quay-credentials.yaml"
echo "       # Edit quay-credentials.yaml — add your base64-encoded docker config"
echo "       oc apply -f quay-credentials.yaml -n $NAMESPACE"
echo "       oc secret link pipeline-sa quay-credentials --for=pull,mount -n $NAMESPACE"
echo ""
echo "  2. Run a pipeline:"
echo "       $SCRIPT_DIR/run-pipeline.sh catalog"
