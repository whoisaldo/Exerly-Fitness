#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
mode="${1:-build}"
shift || true
if [[ "$mode" == release-check ]]; then
  version="$(xcodebuild -version | awk '/Xcode/ {print $2}')"
  sdk="$(xcrun --sdk iphoneos --show-sdk-version)"
  if [[ "${version%%.*}" -lt 26 || "${sdk%%.*}" -lt 26 ]]; then
    echo "Release requires Xcode 26+ and iOS SDK 26+. Found Xcode $version, SDK $sdk." >&2
    exit 1
  fi
  exit 0
fi
args=(-project apps/ios/Exerly.xcodeproj -scheme Exerly -derivedDataPath "${EXERLY_DERIVED_DATA:-.deriveddata}")
if [[ "$mode" == test ]]; then
  if [[ "${EXERLY_FIXTURE_EXTERNAL:-0}" != 1 ]]; then
    if curl -fsS --max-time 1 http://127.0.0.1:39001/__test/ready >/dev/null 2>&1; then
      echo "Port 39001 already serves a fixture. Set EXERLY_FIXTURE_EXTERNAL=1 to use it explicitly." >&2
      exit 1
    fi
    mkdir -p artifacts
    node scripts/ios-fixture-api.cjs > artifacts/ios-fixture-api.log 2>&1 &
    fixture_pid=$!
    trap 'kill "$fixture_pid" 2>/dev/null || true; wait "$fixture_pid" 2>/dev/null || true' EXIT
    for attempt in {1..50}; do
      if curl -fsS --max-time 1 http://127.0.0.1:39001/__test/ready >/dev/null 2>&1; then break; fi
      kill -0 "$fixture_pid" 2>/dev/null || { cat artifacts/ios-fixture-api.log >&2; exit 1; }
      sleep 0.2
    done
    curl -fsS --max-time 1 http://127.0.0.1:39001/__test/ready >/dev/null
  fi
  if [[ -n "${EXERLY_TEST_DESTINATION:-}" ]]; then
    destination="$EXERLY_TEST_DESTINATION"
  else
    device="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); print(next(d["udid"] for k,v in data["devices"].items() if "iOS" in k for d in v if "iPhone" in d["name"]))')"
    destination="platform=iOS Simulator,id=$device"
  fi
  # Simulator ad-hoc signing supplies the entitlements Keychain requires.
  xcodebuild "${args[@]}" -destination "$destination" CODE_SIGN_IDENTITY=- test "$@"
  exit $?
fi
exec xcodebuild "${args[@]}" -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build "$@"
