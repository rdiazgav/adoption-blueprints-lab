#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-retailflow}"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC}  $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "RetailFlow smoke test"
echo "Namespace: $NAMESPACE"
echo "-------------------------------------------"

# Find a running pod to use as the curl executor
EXEC_POD=$(oc get pod -n "$NAMESPACE" \
  -l "app.kubernetes.io/name=frontend" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$EXEC_POD" ]]; then
  echo "ERROR: No running frontend pod found in namespace '$NAMESPACE'."
  echo "       Make sure RetailFlow is deployed: oc get pods -n $NAMESPACE"
  exit 1
fi

echo "Using pod '$EXEC_POD' as curl executor"
echo ""

# Run a single curl from inside the cluster and return the HTTP status code
check_internal() {
  local name=$1
  local url=$2
  local status

  status=$(oc exec "$EXEC_POD" -c frontend -n "$NAMESPACE" -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null) || status="000"

  if [[ "$status" == "200" ]]; then
    ok "$(printf '%-22s' "$name") — HTTP $status  ($url)"
  else
    fail "$(printf '%-22s' "$name") — HTTP $status  ($url)"
  fi
}

check_internal "frontend"       "http://frontend:3000/health"
check_internal "api-gateway"    "http://api-gateway:8080/q/health/live"
check_internal "orders"         "http://orders:8080/q/health/live"
check_internal "catalog"        "http://catalog:8080/q/health/live"
check_internal "recommendations" "http://recommendations:8000/health"

# payments-v1 and payments-v2 each have their own pod; hit each pod directly
for version in v1 v2; do
  POD=$(oc get pod -n "$NAMESPACE" \
    -l "app.kubernetes.io/name=payments,app.kubernetes.io/version=${version}" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$POD" ]]; then
    fail "$(printf '%-22s' "payments-${version}") — pod not found"
    continue
  fi

  status=$(oc exec "$POD" -c payments -n "$NAMESPACE" -- \
    curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    http://localhost:8080/q/health/live 2>/dev/null) || status="000"

  if [[ "$status" == "200" ]]; then
    ok "$(printf '%-22s' "payments-${version}") — HTTP $status"
  else
    fail "$(printf '%-22s' "payments-${version}") — HTTP $status"
  fi
done

echo "-------------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "Some services failed. Check logs with:"
  echo "  oc logs -l app.kubernetes.io/name=<service> -n $NAMESPACE"
  exit 1
fi

echo "All services are healthy. You are ready to start a workshop."
echo ""
