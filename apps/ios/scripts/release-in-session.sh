#!/usr/bin/env bash
# Runs release.sh in the logged-in user's GUI session.
#
#   apps/ios/scripts/release-in-session.sh [--dry-run|--archive|--upload]
#
# Agents often run in a Background launchd session, where macOS consults only
# the System keychain domain, so Xcode can't find the signing identity that
# release.sh puts in its temporary keychain. A transient job bootstrapped into
# gui/<uid> runs in the Aqua session instead, with the user's search list.
# That job can't read ~/Desktop (privacy protection), so the committed
# apps/ios is exported to ~/Library/Caches/exerly-release/<build> and built
# there; every build comes from a commit. Needs the user logged in. The job is
# removed when the release ends.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---upload}"
[[ "$MODE" =~ ^--(dry-run|archive|upload)$ ]] || { echo 'Usage: release-in-session.sh [--dry-run|--archive|--upload]' >&2; exit 2; }
BUILD="${BUILD:-$(date -u +%y%m%d%H%M)}"
LABEL="studio.sideband.exerly.release.$BUILD"
REPO="$(cd "$ROOT/../.." && pwd)"
git -C "$REPO" diff --quiet HEAD -- apps/ios || { echo 'Commit apps/ios first: releases build from a commit' >&2; exit 2; }
SRC="$HOME/Library/Caches/exerly-release/$BUILD"
[[ ! -e "$SRC" ]] || { echo "Already exists: $SRC" >&2; exit 2; }
mkdir -p "$SRC"
git -C "$REPO" archive "$(git -C "$REPO" rev-parse HEAD)" apps/ios | tar -x -C "$SRC"
WORK="$(mktemp -d "/tmp/exerly-release-session.XXXXXX")"
LOG="$WORK/release.log"
STATUS="$WORK/status"
cleanup() { launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true; }
trap cleanup EXIT
cat > "$WORK/job.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>-c</string>
    <string>cd "$SRC/apps/ios" &amp;&amp; bash scripts/release.sh $MODE &gt; "$LOG" 2&gt;&amp;1; echo \$? &gt; "$STATUS"</string>
  </array>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
    <key>BUILD</key><string>$BUILD</string>
    <key>DEVELOPER_DIR</key><string>${DEVELOPER_DIR:-/Applications/Xcode-26.2.app/Contents/Developer}</string>
    <key>EXERLY_RELEASE_ENVIRONMENT</key><string>${EXERLY_RELEASE_ENVIRONMENT:-staging}</string>
  </dict>
  <key>RunAtLoad</key><true/>
</dict></plist>
EOF
launchctl bootstrap "gui/$(id -u)" "$WORK/job.plist"
echo "Releasing $BUILD from $(git -C "$REPO" rev-parse --short HEAD) in the GUI session; log: $LOG"
until [[ -s "$STATUS" ]]; do sleep 5; done
cat "$LOG"
echo "Release output: $SRC/apps/ios/build/release/$BUILD"
exit "$(cat "$STATUS")"
