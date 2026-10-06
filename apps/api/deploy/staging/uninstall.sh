#!/usr/bin/env bash
# Stops and removes devbox1's Exerly staging service. Data is kept unless --purge.
set -euo pipefail
SERVICE="$HOME/Services/exerly-staging"
LABEL="com.aldo.exerly-staging"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
LC_ALL=C /opt/homebrew/bin/pg_ctl -D "$SERVICE/pgdata" -m fast -w stop 2>/dev/null || true
if [ "${1:-}" = "--purge" ]; then
  rm -rf "$SERVICE"
  echo "Removed the service and its data."
else
  echo "Stopped and removed the service. Data remains in $SERVICE."
fi
