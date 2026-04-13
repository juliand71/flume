#!/bin/bash
# Delete all debug_txn_* transactions for the active debug user.
# This cleans up injected transactions without a full supabase db reset.
# Usage: ./reset-transactions.sh [--user UUID]
set -e

API_URL="${API_URL:-http://localhost:3002}"
USER_HEADER=""

for arg in "$@"; do
  if [[ "$prev" == "--user" ]]; then
    USER_HEADER="-H X-Debug-User-ID:$arg"
    break
  fi
  prev="$arg"
done

echo "==> Deleting all debug transactions..."
curl -sf -X DELETE "$API_URL/debug/transactions" \
  -H "Content-Type: application/json" \
  $USER_HEADER | python3 -m json.tool
