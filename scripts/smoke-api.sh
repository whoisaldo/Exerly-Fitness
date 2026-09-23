#!/usr/bin/env bash
# Boot-smoke the API in local mode (SQLite + mock AI — no external services).
# Starts the server, waits for /ping, asserts /api/health, then shuts it down.
# Used by CI (.github/workflows/ci.yml) and the local pre-push hook.
set -euo pipefail

PORT="${PORT:-3001}"
export DB_MODE="${DB_MODE:-local}"
export JWT_SECRET="${JWT_SECRET:-ci-smoke-secret}"
export PORT

API_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../apps/api" && pwd)"
BASE="http://127.0.0.1:${PORT}"

# A throwaway database per run, so the smoke test never writes into the repo
# and never inherits state from a previous run.
SMOKE_DB="$(mktemp -t exerly-smoke-XXXXXX.db)"
export SQLITE_FILE="$SMOKE_DB"

echo "▶ Starting API (DB_MODE=$DB_MODE) on $BASE ..."
( cd "$API_DIR" && exec node index.js ) &
SERVER_PID=$!

cleanup() {
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -f "$SMOKE_DB"
}
trap cleanup EXIT

# Wait for the server to accept connections (max ~30s).
for _ in $(seq 1 30); do
  if curl -fsS "$BASE/ping" >/dev/null 2>&1; then
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "✖ API process exited before becoming ready" >&2
    exit 1
  fi
  sleep 1
done

echo "▶ Checking /ping ..."
PING="$(curl -fsS "$BASE/ping")"
if [ "$PING" != "pong" ]; then
  echo "✖ /ping returned '$PING' (expected 'pong')" >&2
  exit 1
fi

echo "▶ Checking /api/health ..."
curl -fsS "$BASE/api/health" >/dev/null

echo "▶ Exercising the daily loop (signup, weigh-in, food, summary) ..."
EMAIL="smoke-$$@exerly.test"
TOKEN="$(curl -fsS -X POST "$BASE/signup" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"Smoke\",\"email\":\"$EMAIL\",\"password\":\"smoke-test-password\"}" \
  | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).token')"

if [ -z "$TOKEN" ] || [ "$TOKEN" = "undefined" ]; then
  echo "✖ signup did not return a token" >&2
  exit 1
fi

curl -fsS -X POST "$BASE/api/weight" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" -d '{"weight":80}' >/dev/null

curl -fsS -X POST "$BASE/api/food" -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Smoke food","calories":500,"protein":30,"servings":2}' >/dev/null

CONSUMED="$(curl -fsS "$BASE/api/summary" -H "Authorization: Bearer $TOKEN" \
  | node -pe 'JSON.parse(require("fs").readFileSync(0,"utf8")).consumed.calories')"

if [ "$CONSUMED" != "1000" ]; then
  echo "✖ summary reported $CONSUMED kcal (expected 1000 for 500 x 2 servings)" >&2
  exit 1
fi

echo "✓ API smoke test passed"
