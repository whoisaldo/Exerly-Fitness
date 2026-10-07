# Compact iPhone verification

September 22, 2026. iPhone SE, third generation, iOS 18.6 simulator. Screen size is 375 × 667 points. Xcode 16.4 on devbox1, with the isolated fixture API and synthetic accounts.

`/tmp/exerly-production-small-iphone-v4.xcresult` completed with five UI tests passing, one conditional test skipped and no failures. The skipped browser-return consumer requires the combined cross-client sequence; it passed in the separate [measurement round trip](measurements.md).

The passing SE journeys cover:

- Welcome to sign-in navigation.
- Signup, setup interruption and recovery, target review, a lost setup acknowledgement, yesterday's dinner through the barcode fallback, quantity edits, offline relaunch and reconnection with one server record.
- Legacy account repair that asks only for missing information and does not create a fresh weigh-in.
- Body measurement creation, offline edit/relaunch, synchronized deletion and undo.
- Yesterday's explicit logging status and note surviving offline relaunch, then synchronizing without changing today.

The app tests originally used full-screen swipes that could jump past a control on the SE. The helper now uses shorter drags, recognizes sheet toolbar buttons, and dismisses a keyboard when it covers the next field. A later run also exposed setup drafts shared between reset fixture databases. Their SQLite IDs restart, so Debug storage namespaces now include the same per-test UUID used by the test keychain and SwiftData store. That UUID persists across relaunches within a test. Normal application namespaces are unchanged.

Earlier SE runs v1 through v3 were interrupted during failure investigation and harness fixes. They are not passing-suite evidence. V4 is the first completed passing run.

The follow-up `/tmp/exerly-production-small-iphone-v5.xcresult` passed all 31 unit tests and the selected signup/barcode/offline-relaunch UI test. It verifies the final scroll helper adjustment, which treats a virtualized row with zero height as outside the visible list.

Twelve captures from v4 are saved in [small-iphone](small-iphone/), including:

- [Setup target review](small-iphone/setup-target-review.png)
- [150 ml dinner review](small-iphone/yesterday-dinner-150ml.png)
- [Diary status after synchronization](small-iphone/diary-status-synchronized.png)
- [Measurement undo](small-iphone/measurement-synchronized-undo.png)
- [Legacy repair](small-iphone/legacy-repair-missing-activity.png)

These screens were inspected for the tested content at the standard text size. This result does not establish every Dynamic Type size, a VoiceOver audit, iPad layout, physical camera recognition or signed HealthKit behavior.
