#!/bin/bash
# Usage: ./test-auth.sh <email> <password>
# Tests JWT auth against the local budget API.

set -e

EMAIL="${1:?Usage: $0 <email> <password>}"
PASSWORD="${2:?Usage: $0 <email> <password>}"

SUPABASE_URL="https://ewbhprkvtduvbcvzqzlz.supabase.co"
ANON_KEY="sb_publishable_uBuAgwEznZZBISVOtLXeVQ_fDLvzY1K"
API_URL="http://localhost:3002"

echo "==> Signing in as $EMAIL..."
RESPONSE=$(curl -sf -X POST "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

TOKEN=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo ""
echo "==> JWT header (alg + kid):"
echo "$TOKEN" | cut -d. -f1 | base64 -d 2>/dev/null | python3 -m json.tool

echo ""
echo "==> GET $API_URL/budget/accounts"
curl -sf -H "Authorization: Bearer $TOKEN" "$API_URL/budget/accounts" | python3 -m json.tool
