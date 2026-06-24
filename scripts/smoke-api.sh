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

echo "▶ Starting API (DB_MODE=$DB_MODE) on $BASE ..."
# Run from the API dir so ./fitness-local.db resolves the same as `npm start`.
( cd "$API_DIR" && exec node index.js ) &
SERVER_PID=$!

cleanup() {
  if kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
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

echo "✓ API smoke test passed"
