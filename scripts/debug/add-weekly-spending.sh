#!/bin/bash
# Simulate a typical week of flex spending (last 7 days).
# Usage: ./add-weekly-spending.sh [--user UUID]
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

# Helper: date N days ago
daysago() { date -v-${1}d +%Y-%m-%d 2>/dev/null || date -d "$1 days ago" +%Y-%m-%d; }

echo "==> Adding a week of typical spending..."
curl -sf -X POST "$API_URL/debug/transactions" \
  -H "Content-Type: application/json" \
  $USER_HEADER \
  -d "$(cat <<EOF
{
  "transactions": [
    {"name": "TRADER JOES #123",   "amount": 72.45,  "date": "$(daysago 6)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_GROCERIES"}},
    {"name": "WHOLE FOODS MKT",    "amount": 58.30,  "date": "$(daysago 2)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_GROCERIES"}},
    {"name": "STARBUCKS #8832",    "amount": 6.25,   "date": "$(daysago 5)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_COFFEE"}},
    {"name": "CHIPOTLE #4521",     "amount": 14.85,  "date": "$(daysago 4)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_RESTAURANT"}},
    {"name": "THAI GARDEN REST",   "amount": 38.50,  "date": "$(daysago 1)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_RESTAURANT"}},
    {"name": "SHELL OIL #4412",    "amount": 48.90,  "date": "$(daysago 3)", "personal_finance_category": {"primary": "TRANSPORTATION", "detailed": "TRANSPORTATION_GAS"}},
    {"name": "AMAZON.COM",         "amount": 34.99,  "date": "$(daysago 2)", "personal_finance_category": {"primary": "GENERAL_MERCHANDISE", "detailed": "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}}
  ]
}
EOF
)" | python3 -m json.tool
