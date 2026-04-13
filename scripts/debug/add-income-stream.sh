#!/bin/bash
# Add a full month of biweekly income (2 paychecks, 14 days apart).
# Usage: ./add-income-stream.sh [amount] [name] [--user UUID]
set -e

API_URL="${API_URL:-http://localhost:3002}"
AMOUNT="${1:-2800}"
NAME="${2:-ACME CORP PAYROLL}"
USER_HEADER=""

for arg in "$@"; do
  if [[ "$prev" == "--user" ]]; then
    USER_HEADER="-H X-Debug-User-ID:$arg"
    break
  fi
  prev="$arg"
done

daysago() { date -v-${1}d +%Y-%m-%d 2>/dev/null || date -d "$1 days ago" +%Y-%m-%d; }

echo "==> Adding biweekly income: 2x \$$AMOUNT $NAME"
curl -sf -X POST "$API_URL/debug/transactions" \
  -H "Content-Type: application/json" \
  $USER_HEADER \
  -d "$(cat <<EOF
{
  "transactions": [
    {"name": "$NAME", "amount": -$AMOUNT, "date": "$(daysago 14)", "personal_finance_category": {"primary": "INCOME", "detailed": "INCOME_WAGES"}},
    {"name": "$NAME", "amount": -$AMOUNT, "date": "$(daysago 0)",  "personal_finance_category": {"primary": "INCOME", "detailed": "INCOME_WAGES"}}
  ]
}
EOF
)" | python3 -m json.tool
