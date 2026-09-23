# Offline nutrition verification

Date: September 21, 2026. devbox1 / Apple M1 Max / macOS 15.7.9.

The user selected simulator end-to-end checks. This run used Xcode 16.4 and an iPhone 16 Pro simulator on iOS 18.6, against the real API with an isolated SQLite database. Only the external food provider was replaced by a deterministic synthetic fixture.

The full journey passed in `/tmp/exerly-production-offline-e2e-v2.xcresult`:

1. Create an account through the native UI.
2. Enter metric measurements, terminate during setup, and restore the exact answers.
3. Select weight loss, review server-calculated targets, and finish with the successful HTTP acknowledgement deliberately dropped.
4. Enter the initialized diary; select yesterday's dinner; use the simulator's manual barcode fallback.
5. Log 1.5 × 100 ml. Verify one server entry, 90 kcal, 60 mg sodium and a volume basis.
6. Edit the same entry to 0.75 servings online.
7. Make the API unavailable, relaunch, open the cached diary, and edit to 0.5 servings.
8. Terminate and relaunch again; verify the pending quantity survives.
9. Restore the API, reconnect, and verify the same single server entry now contains 30 kcal.

Six screenshots are saved in [offline-simulator](offline-simulator/). The offline and reconnected captures were visually reviewed: the pending label disappears after synchronization, the portion remains 100 ml, and the selected dinner date is retained. No target is shown for the day before this new account's first target version.

The same run passed 16 native unit tests covering startup, draft migration, rotation, unit conversions, immutable operation identities, account isolation, dependent edits and versioned SwiftData migration. A later conflict-resolution test and cached-first startup improvements are undergoing the next run.

SQLite passed 115 API tests after legacy account repair. MongoDB 7.0.24 passed the preceding 113-test suite, including transactions, concurrent writes, conflict revisions, deletion markers, explicit restore and change-feed ordering. The repair additions need the next Mongo run.

The first expanded UI run failed because automation tapped a list entry beneath the custom tab bar. The harness now scrolls that entry clear of the bar. This failure was not counted as a successful run.

September 22 follow-up: the completed measurement batch reran the full food journey alongside setup repair and measurement recovery. Later native unit coverage reached 31 passing tests, and both database suites reached 120. See [measurement verification](measurements.md) and [diary-status verification](diary-status.md) for the later result bundles and their exact scope.

This evidence establishes the listed simulator workflows. It does not establish physical camera detection, signed HealthKit behavior, provider catalog coverage, App Store upload eligibility, or the beta observation gates. The original unowned local model definitions remain in schema V1, and V2 adds account-scoped synchronization records using a [SwiftData migration plan](https://developer.apple.com/documentation/swiftdata/modelcontainer).
