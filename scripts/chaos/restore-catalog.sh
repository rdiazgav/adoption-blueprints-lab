#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=retailflow

echo "==> Restoring catalog deployment to 1 replica..."
oc scale deployment catalog --replicas=1 -n "${NAMESPACE}"
echo "==> Done."
