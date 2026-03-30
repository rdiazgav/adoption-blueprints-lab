#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=retailflow

echo "==> Starting port-forward to api-gateway..."
oc port-forward deployment/api-gateway 8080:8080 -n "${NAMESPACE}" &
PF_PID=$!
sleep 2

GATEWAY_URL="http://localhost:8080"
CHAOS_ENABLE="${GATEWAY_URL}/api/products/chaos/enable"
CHAOS_DISABLE="${GATEWAY_URL}/api/products/chaos/disable"

echo "==> Enabling chaos mode on catalog via ${CHAOS_ENABLE} ..."
curl -s "${CHAOS_ENABLE}" | cat
echo ""

echo ""
echo "==> Catalog is now returning 503 on all product endpoints."
echo "    Envoy will record consecutive 5xx errors and eject the host after 3 failures."
echo ""
echo "    Open Kiali and navigate to Graph > retailflow to watch the circuit open."
echo "    Kiali URL:"
echo "      https://$(oc get route kiali -n istio-system -o jsonpath='{.spec.host}' 2>/dev/null || echo '<kiali-route>')"
echo ""
echo "==> Watching pods for 30 seconds (Ctrl-C to skip)..."
oc get pods -n "${NAMESPACE}" -w &
WATCH_PID=$!
sleep 30
kill "${WATCH_PID}" 2>/dev/null || true

echo ""
echo "==> Disabling chaos mode on catalog via ${CHAOS_DISABLE} ..."
curl -s "${CHAOS_DISABLE}" | cat
echo ""

kill "${PF_PID}" 2>/dev/null || true

echo ""
echo "==> Chaos disabled. Watch Kiali to see the circuit close as catalog recovers."
