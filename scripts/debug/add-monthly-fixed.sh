#!/bin/bash
# Add a month's worth of fixed expenses for the active debug user.
# Usage: ./add-monthly-fixed.sh [--user UUID]
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

echo "==> Adding monthly fixed expenses..."
curl -sf -X POST "$API_URL/debug/transactions" \
  -H "Content-Type: application/json" \
  $USER_HEADER \
  -d "$(cat <<EOF
{
  "transactions": [
    {"name": "RIVERSIDE APARTMENTS",  "amount": 1450.00, "date": "$(daysago 25)", "personal_finance_category": {"primary": "RENT_AND_UTILITIES", "detailed": "RENT_AND_UTILITIES_RENT"}},
    {"name": "CITY ELECTRIC CO",      "amount": 98.00,   "date": "$(daysago 20)", "personal_finance_category": {"primary": "RENT_AND_UTILITIES", "detailed": "RENT_AND_UTILITIES_ELECTRICITY"}},
    {"name": "COMCAST INTERNET",      "amount": 80.00,   "date": "$(daysago 18)", "personal_finance_category": {"primary": "RENT_AND_UTILITIES", "detailed": "RENT_AND_UTILITIES_INTERNET"}},
    {"name": "T-MOBILE WIRELESS",     "amount": 45.00,   "date": "$(daysago 15)", "personal_finance_category": {"primary": "RENT_AND_UTILITIES", "detailed": "RENT_AND_UTILITIES_TELEPHONE"}},
    {"name": "STATE FARM INS",        "amount": 120.00,  "date": "$(daysago 12)", "personal_finance_category": {"primary": "LOAN_PAYMENTS", "detailed": "LOAN_PAYMENTS_INSURANCE_PAYMENT"}},
    {"name": "SPOTIFY PREMIUM",       "amount": 10.99,   "date": "$(daysago 10)", "personal_finance_category": {"primary": "GENERAL_SERVICES", "detailed": "GENERAL_SERVICES_SUBSCRIPTIONS"}},
    {"name": "NETFLIX",               "amount": 15.49,   "date": "$(daysago 8)",  "personal_finance_category": {"primary": "GENERAL_SERVICES", "detailed": "GENERAL_SERVICES_SUBSCRIPTIONS"}}
  ]
}
EOF
)" | python3 -m json.tool
