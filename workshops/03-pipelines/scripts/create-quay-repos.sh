#!/bin/bash
set -euo pipefail

# Usage: QUAY_USER=<user> QUAY_TOKEN=<token> ./create-quay-repos.sh
#
# Creates public RetailFlow repositories in quay.io via the Quay API.
# Treats 201 (created) and 400 "Repository already exists" as success.

QUAY_API="https://quay.io/api/v1/repository"
SERVICES=(api-gateway orders catalog payments recommendations frontend)

# ── Validate required env vars ────────────────────────────────────────────────
if [[ -z "${QUAY_USER:-}" ]]; then
  echo "ERROR: QUAY_USER environment variable is not set." >&2
  echo "  Export your Quay.io username: export QUAY_USER=<your-quay-username>" >&2
  exit 1
fi
if [[ -z "${QUAY_TOKEN:-}" ]]; then
  echo "ERROR: QUAY_TOKEN environment variable is not set." >&2
  echo "  Generate a token at: https://quay.io/user/<username>?tab=settings (CLI Password / Robot Accounts)" >&2
  echo "  Export it: export QUAY_TOKEN=<token>" >&2
  exit 1
fi

# ── Counters ──────────────────────────────────────────────────────────────────
CREATED=0
EXISTED=0
FAILED=0
FAILED_SERVICES=()

echo "==> Creating RetailFlow repositories in quay.io/${QUAY_USER}..."
echo ""

for SERVICE in "${SERVICES[@]}"; do
  REPO_NAME="retailflow-${SERVICE}"
  DESCRIPTION="RetailFlow ${SERVICE} — adoption-blueprints-lab"

  # Capture HTTP status code; body goes to a temp file so we can inspect it on non-201
  BODY=$(mktemp)
  HTTP_CODE=$(curl -s \
    -o "$BODY" \
    -w "%{http_code}" \
    -X POST "$QUAY_API" \
    -H "Authorization: Bearer ${QUAY_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"namespace\": \"${QUAY_USER}\",
      \"repository\": \"${REPO_NAME}\",
      \"visibility\": \"public\",
      \"description\": \"${DESCRIPTION}\",
      \"repo_kind\": \"image\"
    }")

  if [[ "$HTTP_CODE" == "201" ]]; then
    echo "  [created]  ${REPO_NAME}"
    CREATED=$((CREATED + 1))
  elif [[ "$HTTP_CODE" == "400" ]] && grep -q "Repository already exists" "$BODY" 2>/dev/null; then
    echo "  [exists]   ${REPO_NAME}"
    EXISTED=$((EXISTED + 1))
  else
    echo "  [FAILED]   ${REPO_NAME}  (HTTP ${HTTP_CODE}: $(cat "$BODY"))"
    FAILED=$((FAILED + 1))
    FAILED_SERVICES+=("$REPO_NAME")
  fi

  rm -f "$BODY"
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "─────────────────────────────────────────────"
echo "  Created:        ${CREATED}"
echo "  Already existed: ${EXISTED}"
echo "  Failed:         ${FAILED}"
echo "─────────────────────────────────────────────"

if [[ "${#FAILED_SERVICES[@]}" -gt 0 ]]; then
  echo ""
  echo "Failed repositories:"
  for r in "${FAILED_SERVICES[@]}"; do
    echo "  - $r"
  done
  echo ""
  echo "Check your QUAY_TOKEN has 'Create Repositories' permission in quay.io." >&2
  exit 1
fi

echo ""
echo "All repositories ready at: https://quay.io/${QUAY_USER}"
