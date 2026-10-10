#!/usr/bin/env bash
# Runs the UI test suite across several simulators, one fixture API each.
#
#   OUT=<dir> apps/ios/scripts/uitest-shards.sh <udid>:<port> [<udid>:<port> ...]
#
# Every test method in ExerlyUITests is dealt round-robin to the shards, so
# each shard gets a similar mix. TESTS=<file> runs only the identifiers listed
# in it (ExerlyUITests/Class/testMethod, one per line). Start each fixture
# first: EXERLY_FIXTURE_PORT=<port> node scripts/ios-fixture-api.cjs.
# Build for testing first (capture.sh with BUILD=1). Prints a summary.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
: "${OUT:?Set OUT to a directory}"
[[ "$#" -gt 0 ]] || { echo 'Name at least one <udid>:<port> shard' >&2; exit 2; }
mkdir -p "$OUT"
if [[ -n "${TESTS:-}" ]]; then
  cp "$TESTS" "$OUT/all.txt"
else
  # A file can hold more than one test class; each method belongs to the class above it.
  awk 'FNR == 1 { class = "" }
       match($0, /^(final )?class [A-Za-z]+: ExerlyUITestCase/) { split(substr($0, RSTART, RLENGTH), w, /[ :]+/); class = w[w[1] == "final" ? 3 : 2] }
       class != "" && match($0, /^    func test[A-Za-z0-9_]*\(/) { print "ExerlyUITests/" class "/" substr($0, RSTART + 9, RLENGTH - 10) }' \
    "$ROOT"/apps/ios/ExerlyUITests/*.swift > "$OUT/all.txt"
fi
count=$#
pids=()
index=0
for shard in "$@"; do
  sim="${shard%%:*}" port="${shard##*:}"
  awk -v n="$count" -v i="$index" 'NR % n == i' "$OUT/all.txt" > "$OUT/shard-$index.txt"
  # shellcheck disable=SC2046
  CAPTURE=0 SIM="$sim" PORT="$port" OUT="$OUT/shard-$index" \
    "$ROOT/apps/ios/scripts/capture.sh" $(cat "$OUT/shard-$index.txt") > "$OUT/shard-$index.log" 2>&1 &
  pids+=($!)
  index=$((index + 1))
done
for pid in "${pids[@]}"; do wait "$pid" || true; done
passed=$(cat "$OUT"/shard-*/test.log | grep -c "Test Case .* passed" || true)
failed=$(cat "$OUT"/shard-*/test.log | grep "Test Case .* failed" | sed 's/.*\[ExerlyUITests\.\([A-Za-z]*\) \(test[A-Za-z0-9_]*\)\].*/\1\/\2/' || true)
echo "Passed: $passed of $(wc -l < "$OUT/all.txt")"
if [[ -n "$failed" ]]; then echo "Failed:"; echo "$failed"; exit 1; fi
