#!/usr/bin/env bash
# Opens the app on a simulator for remote control through files; see
# ExerlyUITests/DriverUITests.swift for the command format.
#
#   SIM=<udid> PORT=<fixture port> DIR=<folder> apps/ios/scripts/drive.sh
#
# Append commands to $DIR/commands.jsonl; read $DIR/step-N.png and .txt,
# where N is in $DIR/latest. NEW_USER=1 starts signed out instead of with a
# week of synthetic history. Build for testing first (capture.sh BUILD=1).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-26.2.app/Contents/Developer}"
: "${SIM:?Set SIM}" "${PORT:?Set PORT}" "${DIR:?Set DIR}"
curl -fsS --max-time 2 "http://127.0.0.1:$PORT/__test/ready" >/dev/null || { echo "No fixture on $PORT" >&2; exit 2; }
mkdir -p "$DIR"
TEST_RUNNER_EXERLY_DRIVER_DIR="$DIR" TEST_RUNNER_EXERLY_DRIVER_NEW_USER="${NEW_USER:-0}" \
TEST_RUNNER_EXERLY_UI_FIXTURE_URL="http://127.0.0.1:$PORT" \
  xcodebuild -project "$ROOT/apps/ios/Exerly.xcodeproj" -scheme Exerly -derivedDataPath "$ROOT/.deriveddata" \
  -destination "platform=iOS Simulator,id=$SIM" CODE_SIGN_IDENTITY=- \
  -only-testing:ExerlyUITests/DriverUITests/testDrive test-without-building > "$DIR/driver.log" 2>&1
