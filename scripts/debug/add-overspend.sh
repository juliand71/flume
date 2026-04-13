#!/bin/bash
# Pump in flex transactions that blow past typical budget targets.
# Total: ~$1,000-1,200 in flex spending over the last 7 days.
# Usage: ./add-overspend.sh [--user UUID]
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

daysago() { date -v-${1}d +%Y-%m-%d 2>/dev/null || date -d "$1 days ago" +%Y-%m-%d; }

echo "==> Adding overspend transactions (dining + shopping + entertainment)..."
curl -sf -X POST "$API_URL/debug/transactions" \
  -H "Content-Type: application/json" \
  $USER_HEADER \
  -d "$(cat <<EOF
{
  "transactions": [
    {"name": "NOBU RESTAURANT",     "amount": 142.00,  "date": "$(daysago 7)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_RESTAURANT"}},
    {"name": "DOORDASH",            "amount": 48.30,   "date": "$(daysago 6)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_RESTAURANT"}},
    {"name": "UBER EATS",           "amount": 35.75,   "date": "$(daysago 5)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_RESTAURANT"}},
    {"name": "SUSHI HOUSE",         "amount": 78.50,   "date": "$(daysago 4)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_RESTAURANT"}},
    {"name": "DOORDASH",            "amount": 62.20,   "date": "$(daysago 3)", "personal_finance_category": {"primary": "FOOD_AND_DRINK", "detailed": "FOOD_AND_DRINK_RESTAURANT"}},
    {"name": "AMAZON.COM",          "amount": 189.99,  "date": "$(daysago 5)", "personal_finance_category": {"primary": "GENERAL_MERCHANDISE", "detailed": "GENERAL_MERCHANDISE_ONLINE_MARKETPLACES"}},
    {"name": "BEST BUY #7741",      "amount": 149.99,  "date": "$(daysago 3)", "personal_finance_category": {"primary": "GENERAL_MERCHANDISE", "detailed": "GENERAL_MERCHANDISE_ELECTRONICS"}},
    {"name": "ZARA #0221",          "amount": 87.50,   "date": "$(daysago 2)", "personal_finance_category": {"primary": "GENERAL_MERCHANDISE", "detailed": "GENERAL_MERCHANDISE_CLOTHING_AND_ACCESSORIES"}},
    {"name": "STUBHUB TICKETS",     "amount": 120.00,  "date": "$(daysago 1)", "personal_finance_category": {"primary": "ENTERTAINMENT", "detailed": "ENTERTAINMENT_SPORTING_EVENTS_AMUSEMENT_PARKS_AND_MUSEUMS"}},
    {"name": "AMC THEATRES",        "amount": 32.00,   "date": "$(daysago 1)", "personal_finance_category": {"primary": "ENTERTAINMENT", "detailed": "ENTERTAINMENT_TV_AND_MOVIES"}}
  ]
}
EOF
)" | python3 -m json.tool
