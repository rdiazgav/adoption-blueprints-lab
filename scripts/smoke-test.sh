#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-retailflow}"
PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC}  $1"; ((FAIL++)); }

check() {
  local name=$1
  local url=$2
  local status

  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000")

  if [[ "$status" == "200" ]]; then
    ok "$(printf '%-20s' "$name") — HTTP $status"
  else
    fail "$(printf '%-20s' "$name") — HTTP $status  ($url)"
  fi
}

echo ""
echo "RetailFlow smoke test"
echo "Namespace: $NAMESPACE"
echo "-------------------------------------------"

FRONTEND_HOST=$(oc get route frontend -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
API_GW_HOST=$(oc get route api-gateway -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [[ -z "$FRONTEND_HOST" ]]; then
  echo "ERROR: Could not find route for 'frontend' in namespace '$NAMESPACE'"
  echo "       Make sure RetailFlow is deployed: oc get routes -n $NAMESPACE"
  exit 1
fi

check "frontend"         "https://${FRONTEND_HOST}"
check "api-gateway"      "https://${API_GW_HOST}/q/health/live"

for svc in orders catalog; do
  POD=$(oc get pod -n "$NAMESPACE" -l "app=${svc}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$POD" ]]; then
    fail "$(printf '%-20s' "$svc") — pod not found"
    continue
  fi
  status=$(oc exec "$POD" -n "$NAMESPACE" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/q/health/live 2>/dev/null || echo "000")
  if [[ "$status" == "200" ]]; then
    ok "$(printf '%-20s' "$svc") — HTTP $status"
  else
    fail "$(printf '%-20s' "$svc") — HTTP $status"
  fi
done

for svc in payments-v1 payments-v2; do
  POD=$(oc get pod -n "$NAMESPACE" -l "app=${svc}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$POD" ]]; then
    fail "$(printf '%-20s' "$svc") — pod not found"
    continue
  fi
  status=$(oc exec "$POD" -n "$NAMESPACE" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/q/health/live 2>/dev/null || echo "000")
  if [[ "$status" == "200" ]]; then
    ok "$(printf '%-20s' "$svc") — HTTP $status"
  else
    fail "$(printf '%-20s' "$svc") — HTTP $status"
  fi
done

for svc in recommendations; do
  POD=$(oc get pod -n "$NAMESPACE" -l "app=${svc}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$POD" ]]; then
    fail "$(printf '%-20s' "$svc") — pod not found"
    continue
  fi
  status=$(oc exec "$POD" -n "$NAMESPACE" -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health 2>/dev/null || echo "000")
  if [[ "$status" == "200" ]]; then
    ok "$(printf '%-20s' "$svc") — HTTP $status"
  else
    fail "$(printf '%-20s' "$svc") — HTTP $status"
  fi
done

echo "-------------------------------------------"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "Some services failed. Check logs with:"
  echo "  oc logs -l app=<service-name> -n $NAMESPACE"
  exit 1
fi

echo "All services are healthy. You are ready to start a workshop."
echo ""
