# Food recovery and portion precision

Implemented and verified September 22, 2026 against isolated local APIs and synthetic accounts. This completes the browser food recovery work described below; the [production plan](../MOBILE_PRODUCTION_PLAN.md) remains in progress.

## Implemented behavior

The browser now uses one food diary flow. Quick add, search and recents lead to an editor that retains the selected date and meal. The editor accepts decimal and fractional quantities, serving counts, grams, ounces, millilitres and fluid ounces when the food supplies a compatible basis. It preserves the original entered quantity, so a 35 g entry reopens as 35 g. Unknown nutrients remain blank or visibly unknown, including the diary's macro summary.

Drafts and queued operations live in an IndexedDB document owned by the account and API environment. A local transaction saves the operation and its visible entry before the editor closes. Invalid draft text survives reopening. Separate tabs keep independent editor drafts. Signing out preserves that account's pending food changes without exposing them to another account.

The first transmission freezes the method, path, body and operation key. Lost responses replay that request unchanged. A dependent edit, deletion or restore waits for its predecessor's acknowledgement and uses the acknowledged revision. Replay starts on app entry, reconnection or foregrounding, including when the diary is not open. A storage failure while accepting an acknowledgement leaves the original operation recoverable. Unreadable or newer-format local data remains stored and cannot be overwritten by a background refresh.

Conflict resolution fetches the current server record, including deletion markers, and compares its date, meal, quantity and nutrition with the local version. Keeping a local edit over a server deletion explicitly restores it first. If the reviewed revision changes again, another review is required. A definitively rejected validation request can be corrected using a new operation; its original payload is never changed and replayed under the old key.

The diary supports moving an entry to another date or meal, deleting and restoring the same entry, copying yesterday, and copying selected entries from a meal. Copies use one atomic batch of up to 50 entries, with one operation key and a separate client identity per entry. A migrated entry that gains a client identity still appears once and contributes once to totals.

The API retains unrounded per-basis nutrition separately from rounded logged totals. Calories round to whole kilocalories and other nutrients to two decimal places after scaling. Positive half-way values use the same rounding policy on the API, browser and native client. Revisioned food entries reject later unchecked mutations. Paginated day reads can include deletion markers. Original nutrition, normalized servings and entered quantity reach JSON export.

Native food details now preserve fractional per-basis calories from saved foods, barcode responses and library results. Portion changes and corrected nutrition use that precision. The native diary's entire food row is tappable, including its central spacing. The existing native serving-count editor remains; expanding it to the browser's direct unit and fraction controls is still required.

## Verification

| Check                                       | Result                                                                                   | Evidence                                                                                  |
| ------------------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| API, SQLite                                 | 153 passed; no failures or skips                                                         | [SQLite log](food-recovery/api-sqlite.log)                                                |
| API, MongoDB replica set                    | 153 passed; no failures or skips                                                         | [MongoDB log](food-recovery/api-mongodb.log)                                              |
| Chromium food recovery                      | 14 passed                                                                                | [Food log](food-recovery/chromium-food.log)                                               |
| WebKit food recovery                        | 13 passed, followed by the passing legacy-identity case                                  | [Food log](food-recovery/webkit-food.log), [legacy case](food-recovery/webkit-legacy.log) |
| Broader Chromium regression                 | 64 passed; one native-dependent activity/sleep journey skipped                           | [Regression log](food-recovery/browser-regression.log)                                    |
| Chromium production shell and offline reads | 13 passed                                                                                | [Production log](food-recovery/chromium-production.log)                                   |
| WebKit production shell                     | 3 passed                                                                                 | [Production log](food-recovery/webkit-production.log)                                     |
| iPhone SE, iOS 18.6                         | 68 unit tests and one food UI journey passed                                             | [Native log](food-recovery/iphone-se.log)                                                 |
| iPhone 16 Pro, iOS 18.6                     | One food UI journey passed                                                               | [Native log](food-recovery/iphone-16-pro.log)                                             |
| Unsigned device Release build               | Passed using Xcode 16.4 / SDK 18.5                                                       | [Build log](food-recovery/ios-release-build.log)                                          |
| Production web build                        | Passed; existing large-chunk warning                                                     | [Build log](food-recovery/web-build.log)                                                  |
| TypeScript                                  | Passed                                                                                   | [Typecheck](food-recovery/typecheck.log)                                                  |
| ESLint                                      | No errors; 23 warnings                                                                   | [Lint](food-recovery/eslint.log)                                                          |
| SwiftLint                                   | No errors; 72 warnings                                                                   | [Lint](food-recovery/swiftlint.log)                                                       |
| Changed source and documentation formatting | Passed                                                                                   | [Formatting](food-recovery/format.log)                                                    |
| Live preview video                          | Desktop/mobile playback, seeking, captions, deferred loading and failure fallback passed | [Playback results](food-recovery/preview-video.json)                                      |

The broader browser run preceded the final acknowledgement-storage, decimal-boundary and legacy-identity tests. Those are included in the final focused food runs. The skipped activity/sleep journey requires the shared native fixture and passed in the earlier combined cross-client v12 run; it is not counted as passing here.

The native UI journey seeds a 100 g basis with 99.5 kcal, 3.3333 g protein and 123.4567 mg sodium. It changes 1.5 servings to 0.75, verifies 75 kcal, 2.5 g protein and 92.59 mg sodium on the API, then corrects the basis calories to 200.5 and verifies the resulting 150 kcal entry and JSON export. Both phone sizes pass. These journeys independently verify native/API/export and browser/API/export; this batch does not claim a new shared-account browser/iPhone/browser food round trip.

The production-shell food journey disconnects the actual API and static-server sockets, retains an unfinished 35 g draft across closed tabs, saves it offline, closes and reopens the tab again, and reconnects to create exactly one server entry. It runs with the production service worker enabled in both engines. The remote HTTP development preview intentionally does not install a service worker; the automated production tests use their own eligible local origin.

### Reproductions resolved

- The initial native UI test found that tapping the middle of a short food row did nothing because the label's spacer was outside its hit target. Making the whole row interactive fixes the journey. A later test selector was narrowed because both the heading and nutrition facts correctly display “75 kcal”.
- Water and diary API tests assumed UTC Today while their fixture account used America/Detroit. Running after UTC midnight exposed the mismatch. They now derive Today from the account's saved time zone; API date behavior did not change for this fix.
- API rounding via decimal string formatting disagreed with native rounding for values such as 2.675. The boundary regression now expects 2.68 while retaining 2.675 in the original snapshot.
- A server-assigned client identity could leave both the legacy alias and the new identity in a combined diary view. Entries now reconcile by server ID as well, and the regression verifies one row and one contribution to the calorie total after reopening.

## Captures

Reviewed captures from the passing runs:

- [iPhone SE portion editor](food-recovery/iphone-se-portion.png) and [iPhone 16 Pro portion editor](food-recovery/iphone-16-pro-portion.png).
- Chromium [reopened offline draft](food-recovery/chromium-offline-draft.png) and [pending food diary](food-recovery/chromium-offline-pending.png).
- WebKit [reopened offline draft](food-recovery/webkit-offline-draft.png) and [pending food diary](food-recovery/webkit-offline-pending.png).

The browser captures show the saved 35 kcal entry, unknown macros and an explicit pending state. Food controls fit the phone width and selects retain their 44 px height. The existing global navigation still needs the plan's mobile navigation work. The native screen scrolls on iPhone SE; quantity and meal controls remain reachable.

Native result bundles remain in `artifacts/food-precision-native-v3.xcresult` and `artifacts/food-precision-native-small-v1.xcresult`. These are simulator checks, not signed distribution or physical-device evidence.

## Reproduce

```sh
EXERLY_TEST_DB=sqlite npm test
npm run test:mongo
npx playwright test apps/web/e2e/food-recovery.spec.ts
PLAYWRIGHT_BROWSER=webkit npx playwright test apps/web/e2e/food-recovery.spec.ts
npm run test:web:offline
PLAYWRIGHT_BROWSER=webkit npm run test:web:offline
EXERLY_TEST_DESTINATION='platform=iOS Simulator,name=Exerly QA iPhone SE' npm run ios:test -- \
  -only-testing:ExerlyTests \
  -only-testing:ExerlyUITests/ProductionUITests/testFractionalFoodSnapshotSurvivesNativePortionAndNutritionEdits
npm run ios:build -- -configuration Release
npm run typecheck
npm run lint
npm run build:web
```

The native script supplies its own isolated API on 39001. Main browser tests use 3301/39002; production-shell tests use 3306/39006. The MacBook preview remains separate on `http://100.80.149.7:3305`, with its fixture API on 39003 and process logs in `artifacts/preview/`.

## Remaining scope

Complete native quantity controls, personal-library workflows, recipes, saved meals, broader local-data migrations and food portability. The whole plan also retains training, navigation, account lifecycle, accessibility and operational release work. These tests do not close the Xcode 26 release-toolchain gate, physical-device checks, staging verification or signed App Store distribution. No live production API or App Store release was changed by this batch.
