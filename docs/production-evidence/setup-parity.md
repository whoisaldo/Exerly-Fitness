# Browser and native setup

September 22, 2026. Synthetic accounts use the real API with an isolated SQLite database. Native checks run in Xcode 16.4 on iOS 18.6 simulators.

## Implemented behavior

Browser startup reads `/api/bootstrap` and routes incomplete accounts through setup. Legacy repair uses the server's known answers and asks for missing steps. Completing setup updates every mounted session consumer from the completion response. It does not require another successful account request before opening the dashboard.

The browser collects name, adult age, gender identity, measurements, fitness and nutrition goals, activity level, time zone and either a calculation parameter or manual targets. Together with signup, this is six screens. Gender identity and the physiological calculation parameter are separate. Unit changes preserve the original metric measurements. The review screen displays the server preview used for completion.

Every edit is saved locally before upload. Drafts belong to the API environment, account and browser tab. Reload clones the tab's saved draft without overwriting another tab's answers. Older distinct browser drafts remain available for explicit recovery. A storage failure keeps open answers visible and prevents their upload until persistence succeeds. Unreadable saved drafts are retained.

Cloud writes compare revisions. Each pending write keeps its original body and operation identity through response loss and reload, before uploading later edits. Competing versions require a reviewed choice, including their optional preferences and manual targets. Requests time out after 15 seconds and expose a retry. Final submissions remain immutable while their outcome is uncertain. Retry checks setup status first; a successful bootstrap also resolves completion after reload.

Both clients preserve existing optional preferences. Native setup now keeps an independent nutrition goal, custom gender text, equipment and allergy values outside its built-in lists, and independently entered sleep times. The optional native nutrition suggestion follows the fitness goal until the user chooses a nutrition goal explicitly; that choice survives relaunch. Neither client treats a legacy-account repair as a new weigh-in.

## Verified cases

- `/tmp/exerly-setup-web-v2.log` passes the first three browser setup journeys, including each-step reload, back navigation, repeated metric/imperial toggles, independent goals, optional preferences, a reviewed conflict, manual targets, legacy repair and a committed completion whose response is lost.
- `/tmp/exerly-setup-web-full-v1.log` passes 26 standalone browser journeys. Its one skipped consumer requires simulator-created activity and sleep records. The setup tests also cover two tabs with different local answers, choosing the cloud draft, lost draft acknowledgements, a storage quota failure, an immutable submission across reload, API/account isolation and completion detected by bootstrap. Existing session and logging checks remain green.
- `/tmp/exerly-setup-timeout-v1.log` passes a held, committed draft response. Advancing the browser clock releases the controls after the timeout; retry sends the original operation and body.
- `/tmp/exerly-setup-unit-v1.xcresult` passes 43 native unit tests. The new browser-shaped draft test preserves independent goals, unknown preference values, manual targets and sleep times through adoption, a native edit and relaunch.
- `/tmp/exerly-production-cross-client-v8/native-create.xcresult` passes 47 tests with no skips: 43 unit tests and four UI journeys on iPhone SE. The new setup journey resumes a browser-created draft, changes the fitness goal to General Health and the nutrition goal to Gain weight, saves a 75.25 kg target, and reopens the draft. Existing measurement, weight, activity and sleep producers also pass.
- The complete shared run in `/tmp/exerly-production-cross-client-v8/` passes with no failures or skips. One browser journey creates the starting setup draft; all 29 browser journeys then pass after native editing. The four return UI journeys also pass on iPhone SE, including the completed account opening directly into the diary and retaining one initial weigh-in. Targets stay at the manually selected 2,310 kcal, 133 g protein, 246 g carbohydrate and 66 g fat across both clients and export. Retained results: [browser preparation](cross-client-v8/browser-seed.log), [native producers](cross-client-v8/native-create-summary.json), [browser checks](cross-client-v8/browser.log) and [native return checks](cross-client-v8/native-return-summary.json).
- The final native behavior regression passes on iPhone 16 Pro / iOS 18.6. `/tmp/exerly-setup-regression-pro-v1.xcresult` passes 44 unit tests plus fresh signup, interrupted setup, barcode logging and offline relaunch. `/tmp/exerly-setup-repair-pro-v1.xcresult` separately passes legacy repair without a new weigh-in. Neither run has failures or skips. Retained summaries: [fresh account and unit checks](setup-simulator-large/regression-summary.json), [legacy repair](setup-simulator-large/repair-summary.json).
- Visual review raised browser setup and confirmation button contrast from 4.23:1 to 5.70:1 by using a darker violet fill. The native nutrition picker uses the high-contrast primary text color. [Two browser journeys pass again](setup-web/contrast-regression.log) after the button change, and the desktop/mobile review and conflict captures below are refreshed. Native captures record the functional runs before the picker tint adjustment. The final unsigned device build passes in `/tmp/exerly-setup-native-build-v1.log` with Xcode 16.4 / SDK 18.5; it is not a signed-device or distribution check.
- The production web build and TypeScript check pass in `/tmp/exerly-setup-build-v3.log`. The existing bundle-size warning remains. Full web ESLint passes with 30 warnings in `/tmp/exerly-setup-lint-v3.log`; the changed setup files pass without warnings in `/tmp/exerly-setup-changed-lint-v1.log`. Prettier passes in `/tmp/exerly-setup-format-check-v2.log`. SwiftLint passes with 70 warnings in `/tmp/exerly-setup-swiftlint-v3.log` when run with the installed Xcode developer directory.

The first browser setup run exposed an unavailable target preview after a development-mode remount. Setup now restarts preview loading after an interrupted initial sync. Two other failures in that run were incorrect test assertions for the export response shape. The passing runs above supersede that attempt.

## Captures

- [Independent goals on the iPhone SE](setup-simulator-small/setup-independent-nutrition-goal.png)
- [Browser draft reopened on iPhone](setup-simulator-small/setup-native-draft-reopened.png)
- [Completed browser setup returns to the native diary](setup-simulator-small/setup-browser-completion-native-diary.png)
- [Browser review at desktop width](setup-web/setup-review-desktop.png)
- [Browser review at 375 pixels](setup-web/setup-review-mobile.png)
- [Reviewed setup conflict at 375 pixels](setup-web/setup-conflict-mobile.png)
- [Native edits and preferences return to the browser](setup-web/setup-native-to-browser.png)
- [Fresh setup target review on iPhone 16 Pro](setup-simulator-large/setup-target-review.png)
- [Legacy repair on iPhone 16 Pro](setup-simulator-large/legacy-repair-missing-activity.png)

## Remaining foundation work

Post-setup preference editors and local reminder delivery are implemented in the subsequent [preferences batch](preferences.md). The browser does not yet support a full offline application launch. More legacy and corrupt-storage fixtures, VoiceOver and Dynamic Type checks, and the public-release lifecycle and security work remain in the production plan. These simulator results do not close the signed-device, distribution-toolchain or beta-observation gates.
