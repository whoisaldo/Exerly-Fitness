#!/usr/bin/env bash
# Boot-smoke the API on PostgreSQL with mock AI and no other external services.
# Starts the server, waits for /ping, asserts /api/health, runs the daily loop,
# then shuts it down. Used by CI (.github/workflows/ci.yml).
#
# With SMOKE_DATABASE_URL set (CI's service container), it uses that database.
# Otherwise it starts a throwaway cluster on a Unix socket and removes it.
set -euo pipefail

PORT="${PORT:-39101}"
export JWT_SECRET="${JWT_SECRET:-ci-smoke-secret}"
export PORT

API_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../apps/api" && pwd)"
BASE="http://127.0.0.1:${PORT}"

CLUSTER_DIR=""
if [ -n "${SMOKE_DATABASE_URL:-}" ]; then
  export DATABASE_URL="$SMOKE_DATABASE_URL"
else
  CLUSTER_DIR="$(mktemp -d -t exerly-smoke-pg-XXXXXX)"
  LC_ALL=C initdb -D "$CLUSTER_DIR/data" -U exerly -A trust -E UTF8 --no-locale >/dev/null
  LC_ALL=C pg_ctl -D "$CLUSTER_DIR/data" -l "$CLUSTER_DIR/server.log" -w \
    -o "-k $CLUSTER_DIR -c listen_addresses= -F" start >/dev/null
  export DATABASE_URL="postgresql://exerly@localhost/postgres?host=$CLUSTER_DIR"
fi

echo "▶ Starting API (PostgreSQL) on $BASE ..."
( cd "$API_DIR" && exec node index.js ) &
SERVER_PID=$!

cleanup() {
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  if [ -n "$CLUSTER_DIR" ]; then
    LC_ALL=C pg_ctl -D "$CLUSTER_DIR/data" -m immediate -w stop >/dev/null 2>&1 || true
    rm -rf "$CLUSTER_DIR"
  fi
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
