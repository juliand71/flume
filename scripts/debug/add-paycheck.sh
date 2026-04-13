#!/bin/bash
# Add a single income transaction for the active debug user.
# Usage: ./add-paycheck.sh [amount] [name] [--user UUID]
set -e

API_URL="${API_URL:-http://localhost:3002}"
AMOUNT="${1:-2800}"
NAME="${2:-ACME CORP PAYROLL}"
USER_HEADER=""

# Parse --user flag from any position
for arg in "$@"; do
  if [[ "$prev" == "--user" ]]; then
    USER_HEADER="-H X-Debug-User-ID:$arg"
    break
  fi
  prev="$arg"
done

DATE=$(date +%Y-%m-%d)

echo "==> Adding paycheck: $NAME for \$$AMOUNT on $DATE"
curl -sf -X POST "$API_URL/debug/transactions" \
  -H "Content-Type: application/json" \
  $USER_HEADER \
  -d "$(cat <<EOF
{
  "name": "$NAME",
  "amount": -$AMOUNT,
  "date": "$DATE",
  "personal_finance_category": {"primary": "INCOME", "detailed": "INCOME_WAGES"}
}
EOF
)" | python3 -m json.tool
