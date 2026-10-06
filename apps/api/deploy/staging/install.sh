#!/usr/bin/env bash
# Deploys the API from this checkout as devbox1's staging service:
#   http://100.80.149.7:39110 (tailnet), PostgreSQL on a private Unix socket.
# Re-run to redeploy. Data in ~/Services/exerly-staging/pgdata is kept.
# Follows ~/Services/devbox-recovery/README.md: a deployed copy under ~/Services,
# because LaunchAgents can't read ~/Desktop, and one LaunchAgent.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
SERVICE="$HOME/Services/exerly-staging"
LOGS="$HOME/Library/Logs/exerly-staging"
LABEL="com.aldo.exerly-staging"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
NODE="$HOME/.local/share/fnm/node-versions/v22.22.2/installation/bin/node"
PORT=39110

umask 077
mkdir -p "$SERVICE/run" "$LOGS"
chmod 700 "$SERVICE" "$SERVICE/run"

# Stop the API (not PostgreSQL) while the code is replaced.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

# The application, with production dependencies only.
rm -rf "$SERVICE/app.next"
mkdir -p "$SERVICE/app.next/apps"
cp "$REPO/package.json" "$REPO/package-lock.json" "$SERVICE/app.next/"
rsync -a --exclude node_modules --exclude tests --exclude '*.db' --exclude .env "$REPO/apps/api" "$SERVICE/app.next/apps/"
(cd "$SERVICE/app.next" && PATH="$(dirname "$NODE"):$PATH" npm ci --omit=dev --workspace apps/api \
  --include-workspace-root=false --ignore-scripts --no-audit --no-fund >/dev/null)
rm -rf "$SERVICE/app"
mv "$SERVICE/app.next" "$SERVICE/app"
ln -sfn "$NODE" "$SERVICE/node"
install -m 700 "$REPO/apps/api/deploy/staging/run.sh" "$SERVICE/run.sh"

# A private cluster: no TCP listener, socket in a 700 directory.
if [ ! -f "$SERVICE/pgdata/PG_VERSION" ]; then
  LC_ALL=C /opt/homebrew/bin/initdb -D "$SERVICE/pgdata" -U exerly -A trust -E UTF8 --no-locale >/dev/null
fi

if [ ! -f "$SERVICE/staging.env" ]; then
  cat >"$SERVICE/staging.env" <<ENV
NODE_ENV=production
HOST=0.0.0.0
PORT=$PORT
JWT_SECRET=$(openssl rand -hex 32)
DATABASE_URL=postgresql://exerly@localhost/postgres?host=$SERVICE/run
ENV
fi
chmod 600 "$SERVICE/staging.env"

cat >"$PLIST" <<PLISTXML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$SERVICE/run.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOGS/api.log</string>
  <key>StandardErrorPath</key><string>$LOGS/api.log</string>
</dict>
</plist>
PLISTXML

launchctl bootstrap "gui/$(id -u)" "$PLIST"
for _ in $(seq 1 60); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
    echo "Exerly staging is healthy at http://100.80.149.7:$PORT"
    exit 0
  fi
  sleep 1
done
echo "Staging did not become healthy; see $LOGS/api.log" >&2
exit 1
