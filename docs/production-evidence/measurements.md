# Body measurement verification

September 22, 2026. Local Xcode 16.4, iPhone 16 Pro simulator on iOS 18.6, and headless Chrome on devbox1. The test uses the real API and isolated in-memory SQLite. Accounts and readings are synthetic.

The completed round trip is in `/tmp/exerly-production-cross-client-v3/`:

1. The native UI logs an 82.55 cm waist measurement.
2. An offline edit to 81.25 cm survives app termination and relaunch.
3. Reconnection updates the same server record. A synchronized deletion and undo restore that record with the same ID.
4. Chrome signs into that account and reads 81.25 cm. It edits the value, reviews a conflict with a concurrent API update, and saves the reviewed value.
5. The server commits a later 80.5 cm update, but the browser loses the acknowledgement. Reload and retry reuse the operation key without another revision.
6. Browser deletion and undo preserve the record ID. A second measurement entered as 12.5 inches becomes 31.75 cm. Export contains both readings.
7. The native UI signs into the same account and reads 80.5 cm for waist and 31.75 cm for arms.

Run `npm run test:cross-client` on a Mac with Xcode, an available iPhone simulator and Chrome. Set `PLAYWRIGHT_CHANNEL=chromium` after installing the Playwright Chromium browser to use the CI browser. The script owns ports 39001 and 3303 and stops its servers on exit. `EXERLY_DERIVED_DATA`, `EXERLY_TEST_DESTINATION` and `EXERLY_CROSS_CLIENT_EVIDENCE` can override build storage, simulator and evidence paths.

The native producer and consumer passed in `native-create.xcresult` and `native-return.xcresult`. The browser result is in `browser.log`. Standalone browser verification also passed in `/tmp/exerly-production-web-e2e-v2.log` and `/tmp/exerly-production-web-e2e-v3.log`. The latter used the preceding native account directly.

The native unit suite passed 29 tests in `/tmp/exerly-production-measurement-unit-v3.xcresult`. New cases cover disk reopening, account isolation, legacy-record quarantine, atomic explicit import, immutable replay before a dependent edit, and reviewed conflicts. SQLite and MongoDB each passed 118 API tests in their `v9` logs before the next diary-status batch.

Screenshots were inspected:

- [Native offline edit](measurement-simulator/measurement-offline-edit.png)
- [Native synchronized undo](measurement-simulator/measurement-synchronized-undo.png)
- [Browser changes returned to native](measurement-simulator/measurement-browser-return.png)
- [Browser desktop](measurement-web/measurements-desktop.png)
- [Browser mobile](measurement-web/measurements-mobile.png)

The offline and undo captures come from `measurement-e2e-v3.xcresult`. The native return capture comes from the combined run. Browser screenshots may be refreshed by the later standalone run when layout changes are verified; they demonstrate the same final values on a new isolated account.

Legacy measurements never upload automatically. The user confirms ownership, selects supported body records, and imports them in one local transaction. Unsupported legacy weights or units remain on the device and can be exported. Other legacy local record types still need their own recovery flows.

This closes the listed body-measurement simulator and browser checks. It does not establish offline weight logging, HealthKit behavior, photo backup, physical-device reliability, App Store upload eligibility or the beta observation gates. Playwright uses a separate test profile through its documented [browser channels](https://playwright.dev/docs/browsers), without accessing the user's normal browser session.
