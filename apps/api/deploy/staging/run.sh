#!/bin/bash
# Started by the com.aldo.exerly-staging LaunchAgent from ~/Services/exerly-staging.
# Starts the staging PostgreSQL cluster if it isn't running, then runs the API
# in the foreground so launchd can restart it.
set -euo pipefail
SERVICE="$HOME/Services/exerly-staging"
set -a
# shellcheck source=/dev/null
source "$SERVICE/staging.env"
set +a
export LC_ALL=C
if ! /opt/homebrew/bin/pg_ctl -D "$SERVICE/pgdata" status >/dev/null 2>&1; then
  /opt/homebrew/bin/pg_ctl -D "$SERVICE/pgdata" -l "$HOME/Library/Logs/exerly-staging/postgres.log" -w \
    -o "-k $SERVICE/run -c listen_addresses=" start
fi
cd "$SERVICE/app/apps/api"
exec "$SERVICE/node" index.js
