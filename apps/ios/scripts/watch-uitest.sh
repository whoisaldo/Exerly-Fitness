#!/usr/bin/env bash
# Runs the watch app's UI test against its paired phone. The phone's half
# (ExerlyUITests/WatchCompanionUITests) signs into a fixture account with a
# planned workout and checks what the watch logs; the watch's half
# (ExerlyWatchUITests) drives the watch app. Screens the watch test asks for
# are captured with simctl into OUT/screens.
#
#   PHONE=<udid> WATCH=<udid> PORT=<fixture port> OUT=<dir> apps/ios/scripts/watch-uitest.sh
#
# The two simulators must be paired (xcrun simctl pair) and booted, and the
# fixture on PORT running: EXERLY_FIXTURE_PORT=<port> node scripts/ios-fixture-api.cjs.
# BUILD=0 skips building for testing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-26.2.app/Contents/Developer}"
: "${PHONE:?Set PHONE to the iPhone simulator udid}" "${WATCH:?Set WATCH to the paired watch simulator udid}"
: "${PORT:?Set PORT to the fixture port}" "${OUT:?Set OUT to a directory}"
curl -fsS --max-time 2 "http://127.0.0.1:$PORT/__test/ready" >/dev/null || { echo "No fixture on $PORT" >&2; exit 2; }
mkdir -p "$OUT/screens"
project=(-project "$ROOT/apps/ios/Exerly.xcodeproj" -derivedDataPath "$ROOT/.deriveddata-watch" CODE_SIGN_IDENTITY=-)
phone=(-scheme Exerly -destination "platform=iOS Simulator,id=$PHONE")
watch=(-scheme ExerlyWatch -destination "platform=watchOS Simulator,id=$WATCH")
if [[ "${BUILD:-1}" == 1 ]]; then
  xcodebuild "${project[@]}" "${phone[@]}" build-for-testing > "$OUT/build-phone.log" 2>&1 || {
    grep -E 'error:' "$OUT/build-phone.log" | head -20; exit 1; }
  xcodebuild "${project[@]}" "${watch[@]}" build-for-testing > "$OUT/build-watch.log" 2>&1 || {
    grep -E 'error:' "$OUT/build-watch.log" | head -20; exit 1; }
fi
# The watch test asks for a screen by creating <name>.request and waits for it to go.
( while sleep 0.3; do
    for request in "$OUT"/screens/*.request; do
      [[ -e "$request" ]] || continue
      xcrun simctl io "$WATCH" screenshot "${request%.request}.png" >/dev/null 2>&1 || true
      rm -f "$request"
    done
  done ) &
shooter=$!
ready="$OUT/phone.ready"
rm -f "$ready"
TEST_RUNNER_EXERLY_WATCH_COMPANION=1 TEST_RUNNER_EXERLY_UI_FIXTURE_URL="http://127.0.0.1:$PORT" \
TEST_RUNNER_EXERLY_SCREEN_DIR="$OUT/screens" TEST_RUNNER_EXERLY_WATCH_READY="$ready" \
  xcodebuild "${project[@]}" "${phone[@]}" -resultBundlePath "$OUT/phone-$(date +%s).xcresult" \
  -only-testing:ExerlyUITests/WatchCompanionUITests test-without-building > "$OUT/phone.log" 2>&1 &
phone_pid=$!
# The watch would otherwise start from the last run's state while the phone is still signing in.
until [[ -e "$ready" ]] || ! kill -0 "$phone_pid" 2>/dev/null; do sleep 1; done
status=0
TEST_RUNNER_EXERLY_WATCH_COMPANION=1 TEST_RUNNER_EXERLY_SCREEN_DIR="$OUT/screens" \
  xcodebuild "${project[@]}" "${watch[@]}" -resultBundlePath "$OUT/watch-$(date +%s).xcresult" \
  test-without-building > "$OUT/watch.log" 2>&1 || status=$?
# The phone's half waits for the watch; don't let it wait out its timeouts after a failure.
[[ "$status" == 0 ]] || kill "$phone_pid" 2>/dev/null || true
wait "$phone_pid" || status=1
kill "$shooter" 2>/dev/null || true
grep -h -E "Test Case .*(passed|failed|skipped)|error:|XCTAssert" "$OUT/phone.log" "$OUT/watch.log" | head -40
exit $status
