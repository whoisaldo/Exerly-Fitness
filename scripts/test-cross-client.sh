#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

evidence="${EXERLY_CROSS_CLIENT_EVIDENCE:-artifacts/cross-client-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$evidence"
fixture_pid=''
web_pid=''
cleanup() {
  [[ -z "$web_pid" ]] || kill "$web_pid" 2>/dev/null || true
  [[ -z "$fixture_pid" ]] || kill "$fixture_pid" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap 'cross_status=$?; cleanup; exit "$cross_status"' EXIT

if curl -fsS --max-time 1 http://127.0.0.1:39001/__test/ready >/dev/null 2>&1; then
  echo 'Port 39001 is already serving a fixture. Stop that isolated test process before starting a new cross-client run.' >&2
  exit 1
fi
EXTRA_CORS_ORIGINS=http://127.0.0.1:3303 node scripts/ios-fixture-api.cjs > "$evidence/api.log" 2>&1 &
fixture_pid=$!
(
  cd apps/web
  VITE_API_URL=http://127.0.0.1:39001 exec node ../../node_modules/vite/bin/vite.js --host 0.0.0.0 --port 3303 --strictPort
) > "$evidence/web.log" 2>&1 &
web_pid=$!
for attempt in {1..100}; do
  if curl -fsS --max-time 1 http://127.0.0.1:39001/__test/ready >/dev/null 2>&1 && curl -fsS --max-time 1 http://127.0.0.1:3303 >/dev/null 2>&1; then break; fi
  kill -0 "$fixture_pid" 2>/dev/null || { cat "$evidence/api.log" >&2; exit 1; }
  kill -0 "$web_pid" 2>/dev/null || { cat "$evidence/web.log" >&2; exit 1; }
  sleep 0.2
done
curl -fsS --max-time 1 http://127.0.0.1:39001/__test/ready >/dev/null
curl -fsS --max-time 1 http://127.0.0.1:3303 >/dev/null

export EXERLY_FIXTURE_EXTERNAL=1
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3303 PLAYWRIGHT_API_URL=http://127.0.0.1:39001 PLAYWRIGHT_SETUP_STAGE=seed npm run test:web -- apps/web/e2e/setup-cross-client.spec.ts --output "$evidence/browser-seed" > "$evidence/browser-seed.log" 2>&1
echo 'Browser setup draft saved for the simulator.'
producer_args=(-only-testing:ExerlyTests -only-testing:ExerlyUITests/ProductionUITests/testBodyMeasurementOfflineRecoveryAndSynchronizedUndo -only-testing:ExerlyUITests/ProductionUITests/testWeightOfflineRecoveryConflictReviewDeletionAndUndo -only-testing:ExerlyUITests/ProductionUITests/testActivityAndSleepOfflineRecoveryConflictDeletionAndUndo -only-testing:ExerlyUITests/ProductionUITests/testBrowserSetupDraftContinuesOnNative -only-testing:ExerlyUITests/ProductionUITests/testPreferencesDraftRecoveryLostResponseAndReviewedConflict -only-testing:ExerlyUITests/ProductionUITests/testLegacySessionUpgradeRecoversALostResponseAndKeepsOfflineAccount)
if [[ "${EXERLY_CROSS_CLIENT_FULL_NATIVE:-0}" == 1 ]]; then
  bash scripts/ios.sh test -resultBundlePath "$evidence/native-create.xcresult" > "$evidence/native-create.log" 2>&1
else
  bash scripts/ios.sh test "${producer_args[@]}" -resultBundlePath "$evidence/native-create.xcresult" > "$evidence/native-create.log" 2>&1
fi
for journey in testBodyMeasurementOfflineRecoveryAndSynchronizedUndo testWeightOfflineRecoveryConflictReviewDeletionAndUndo testActivityAndSleepOfflineRecoveryConflictDeletionAndUndo testBrowserSetupDraftContinuesOnNative testPreferencesDraftRecoveryLostResponseAndReviewedConflict testLegacySessionUpgradeRecoversALostResponseAndKeepsOfflineAccount; do
  if ! rg -Fq "$journey]' passed" "$evidence/native-create.log"; then
    echo "The native producer $journey was skipped or did not pass." >&2
    exit 1
  fi
done
echo 'Native legacy-session, setup and preferences recovery, plus measurement, weight, activity and sleep synchronization passed.'
PLAYWRIGHT_BASE_URL=http://127.0.0.1:3303 PLAYWRIGHT_API_URL=http://127.0.0.1:39001 PLAYWRIGHT_NATIVE_ACCOUNT=1 PLAYWRIGHT_SETUP_STAGE=finish npm run test:web -- --output "$evidence/browser" > "$evidence/browser.log" 2>&1
echo 'Browser edits, conflict review, lost-response replay, undo and export passed.'
bash scripts/ios.sh test -only-testing:ExerlyUITests/ProductionUITests/testBodyMeasurementWebChangesReturnToNative -only-testing:ExerlyUITests/ProductionUITests/testWeightWebChangesReturnToNative -only-testing:ExerlyUITests/ProductionUITests/testActivityAndSleepWebChangesReturnToNative -only-testing:ExerlyUITests/ProductionUITests/testBrowserSetupCompletionReturnsToNative -only-testing:ExerlyUITests/ProductionUITests/testBrowserPreferencesReturnToNative -resultBundlePath "$evidence/native-return.xcresult" > "$evidence/native-return.log" 2>&1
for journey in testBodyMeasurementWebChangesReturnToNative testWeightWebChangesReturnToNative testActivityAndSleepWebChangesReturnToNative testBrowserSetupCompletionReturnsToNative testBrowserPreferencesReturnToNative; do
  if ! rg -Fq "$journey]' passed" "$evidence/native-return.log"; then
    echo "The native return check $journey was skipped or did not pass." >&2
    exit 1
  fi
done
echo "Native return verification passed. Evidence: $evidence"
