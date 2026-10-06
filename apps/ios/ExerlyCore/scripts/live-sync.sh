#!/usr/bin/env bash
# Runs ExerlyCore's live tests: the Swift API client and sync engine against
# the real API, on a throwaway PostgreSQL cluster that listens on a Unix socket
# only. The API uses the logic agent's scratch port (39102 by default).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
PORT="${EXERLY_LIVE_PORT:-39102}"
WORK="$(mktemp -d -t exerly-live-XXXXXX)"
API_PID=""

cleanup() {
  if [ -n "$API_PID" ] && kill -0 "$API_PID" 2>/dev/null; then
    kill "$API_PID" 2>/dev/null || true
    wait "$API_PID" 2>/dev/null || true
  fi
  LC_ALL=C pg_ctl -D "$WORK/data" -m immediate -w stop >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

if curl -fsS --max-time 1 "http://127.0.0.1:$PORT/ping" >/dev/null 2>&1; then
  echo "Port $PORT is already in use." >&2
  exit 1
fi

LC_ALL=C initdb -D "$WORK/data" -U exerly -A trust -E UTF8 --no-locale >/dev/null
LC_ALL=C pg_ctl -D "$WORK/data" -l "$WORK/postgres.log" -w -o "-k $WORK -c listen_addresses= -F" start >/dev/null

(
  cd "$ROOT/apps/api"
  DATABASE_URL="postgresql://exerly@localhost/postgres?host=$WORK" JWT_SECRET=live-sync-only \
    HOST=127.0.0.1 PORT="$PORT" NODE_ENV=test exec node index.js
) >"$WORK/api.log" 2>&1 &
API_PID=$!

for _ in $(seq 1 50); do
  curl -fsS --max-time 1 "http://127.0.0.1:$PORT/ping" >/dev/null 2>&1 && break
  kill -0 "$API_PID" 2>/dev/null || { cat "$WORK/api.log" >&2; exit 1; }
  sleep 0.2
done

EXERLY_LIVE_API="http://127.0.0.1:$PORT" swift test --package-path "$ROOT/apps/ios/ExerlyCore" --filter LiveSyncTests "$@"
