#!/usr/bin/env bash
set -euo pipefail

TIMEOUT=300  # 5 minutes per step

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
info()    { echo "[INFO]  $*"; }
success() { echo "[OK]    $*"; }
fail()    { echo "[FAIL]  $*" >&2; exit 1; }

wait_for_cmd() {
  local description="$1"
  local deadline=$(( $(date +%s) + TIMEOUT ))
  shift
  info "Waiting for: ${description}"
  until "$@" &>/dev/null; do
    if (( $(date +%s) >= deadline )); then
      fail "Timed out after ${TIMEOUT}s waiting for: ${description}"
    fi
    sleep 5
  done
  success "${description}"
}

# ---------------------------------------------------------------------------
# 1. istiod Ready
# ---------------------------------------------------------------------------
info "Step 1 — Wait for istiod to be Ready in istio-system"
oc wait --for=condition=Ready pod -l app=istiod \
  -n istio-system --timeout="${TIMEOUT}s"
success "istiod is Ready"

# ---------------------------------------------------------------------------
# 2. MutatingWebhookConfiguration exists
# ---------------------------------------------------------------------------
info "Step 2 — Wait for istio-sidecar-injector MutatingWebhookConfiguration"
wait_for_cmd \
  "istio-sidecar-injector MutatingWebhookConfiguration" \
  oc get mutatingwebhookconfiguration istio-sidecar-injector
success "istio-sidecar-injector webhook is present"

# ---------------------------------------------------------------------------
# 3. istio-cni-node DaemonSet ready
# ---------------------------------------------------------------------------
info "Step 3 — Wait for istio-cni-node DaemonSet to be ready in istio-cni"
wait_for_cmd \
  "istio-cni-node DaemonSet to exist" \
  oc get daemonset istio-cni-node -n istio-cni

deadline=$(( $(date +%s) + TIMEOUT ))
until
  DESIRED=$(oc get daemonset istio-cni-node -n istio-cni \
    -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null)
  READY=$(oc get daemonset istio-cni-node -n istio-cni \
    -o jsonpath='{.status.numberReady}' 2>/dev/null)
  [[ -n "$DESIRED" && -n "$READY" && "$DESIRED" -gt 0 && "$READY" -eq "$DESIRED" ]]
do
  if (( $(date +%s) >= deadline )); then
    fail "Timed out after ${TIMEOUT}s waiting for istio-cni-node DaemonSet (desired=${DESIRED:-?} ready=${READY:-?})"
  fi
  info "  istio-cni-node: ${READY:-0}/${DESIRED:-?} ready — retrying in 5s"
  sleep 5
done
success "istio-cni-node DaemonSet is fully ready (${READY}/${DESIRED})"

# ---------------------------------------------------------------------------
# 4. Bounce the ingressgateway pod
# ---------------------------------------------------------------------------
info "Step 4 — Deleting ingressgateway pod so it is recreated with the sidecar"
oc delete pod -n istio-ingress -l istio=ingressgateway --ignore-not-found
success "Ingressgateway pod deleted"

# ---------------------------------------------------------------------------
# 5. Wait for the new pod to be Running
# ---------------------------------------------------------------------------
info "Step 5 — Waiting for new ingressgateway pod to reach Running"
deadline=$(( $(date +%s) + TIMEOUT ))
until
  PHASE=$(oc get pod -n istio-ingress -l istio=ingressgateway \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
  [[ "$PHASE" == "Running" ]]
do
  if (( $(date +%s) >= deadline )); then
    fail "Timed out after ${TIMEOUT}s waiting for ingressgateway pod to be Running (phase=${PHASE:-Pending})"
  fi
  info "  ingressgateway pod phase: ${PHASE:-Pending} — retrying in 5s"
  sleep 5
done
success "Ingressgateway pod is Running"

echo ""
echo "All mesh components are ready."
