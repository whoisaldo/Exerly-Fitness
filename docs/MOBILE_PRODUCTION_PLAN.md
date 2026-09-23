# Exerly Fitness mobile production plan

Prepared September 21, 2026. Revised September 22, 2026 against the newer working tree, implementation ledger, and verification artifacts.

The recommendation is to make Exerly a dependable daily nutrition and training app, with setup, food logging, and workout logging as the first priorities. Build on the existing SwiftUI app and API. Ship the expanded product in stages, with a defined test and release gate for each stage.

This document defines the target product and remaining work. Implementation has begun in the existing workspace; setup, barcode, session, and synchronization foundations have progressed since the original audit. The original planning refresh changed documentation only; implementation batches followed. Use the current-state table below to distinguish implemented foundations from unfinished features. Sections 3 through 13 describe acceptance requirements for the complete product, including behavior already implemented that must be preserved. [MOBILE_PRODUCTION_STATUS.md](MOBILE_PRODUCTION_STATUS.md) records implementation batches and their evidence. The older MASTER_PLAN.md and IOS_HANDOFF.md are historical references, not the current backlog.

"Production ready" means the supported workflows pass their acceptance tests, failures preserve user data and offer a recovery path, and the release has operational monitoring and a rollback procedure.

1. **Start from the September 22 baseline.** Preserve the implemented foundations and close their remaining verification gaps.

   Exerly has a native SwiftUI iOS app, a React web app, and one Node API backed by MongoDB or SQLite. The newer working tree includes six-screen signup/setup, persisted local and server drafts, atomic program initialization, legacy account repair, rotating native sessions, barcode normalization, typed provider outcomes, offline food editing, synchronized body measurements, explicit diary logging status, and historical targets.

   The original audit's setup/program mismatch and stale-weigh-in confidence bugs now have passing regression tests. They are historical failure cases to retain in the suite, not current failures reproduced by this refresh.

   The following table records the earlier planning-refresh checks. Later implementation and test counts are in the delivery ledger.

   | Check                          | September 22 evidence                                                                                        | Limit                                                                                                                                                    |
   | ------------------------------ | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
   | API suite                      | Re-ran with `EXERLY_TEST_DB=sqlite npm test`: 122 passed, zero failed.                                       | Isolated SQLite; not the deployed database or live providers.                                                                                            |
   | Web types                      | Re-ran `npm run typecheck`: passed.                                                                          | Does not replace browser interaction or accessibility tests.                                                                                             |
   | Unsigned iOS build             | Rebuilt through `scripts/ios.sh`: passed using Xcode 16.4 and SDK 18.5.                                      | Not a signed-device test or App Store archive. Two warnings remain: an unlabeled trailing closure in MeasurementsTab and skipped App Intents extraction. |
   | Release SDK gate               | Re-ran `npm run ios:release-check`: correctly failed on the installed Xcode 16.4/SDK 18.5.                   | A supported release toolchain still needs to execute the build and tests.                                                                                |
   | Existing full native result    | Read `/tmp/exerly-production-native-full-v7.xcresult`: 36 passed, one conditional test skipped, zero failed. | Earlier iPhone 16 Pro/iOS 18.6 simulator run. The ledger identifies 31 unit tests and five UI journeys; this refresh did not rerun them.                 |
   | Existing compact-iPhone result | Read `/tmp/exerly-production-small-iphone-v5.xcresult`: 32 passed, zero failed or skipped.                   | Earlier iPhone SE simulator run with 31 unit tests and one selected UI journey; standard text size.                                                      |
   | MongoDB and browser results    | The implementation ledger records 120 API tests on an isolated Mongo replica set and three browser journeys. | Reported existing evidence, not fresh Mongo/browser execution for the current 122-test snapshot. Re-run after subsequent implementation changes.         |

   Fresh planning-check logs are `/tmp/exerly-plan-refresh-20260922-api.log` and `/tmp/exerly-plan-refresh-20260922-ios.log`. Temporary files are useful audit evidence but must not replace retained CI artifacts for a release.

   Visual review used the existing compact-phone setup, diary-status, and measurement screenshots in `docs/production-evidence/small-iphone/`. They show the newer implementation, not a new runtime session during this planning refresh.

   | Area                   | Implemented foundation                                                                                                                                                                                                                                                             | Remaining work before claiming the workflow is complete                                                                                                                                    |
   | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
   | Setup and first launch | Native and browser account/environment-scoped drafts, reviewed cloud conflicts, canonical measurements, independent nutrition goals, server preview, atomic completion, lost-response recovery and legacy repair. Durable post-setup editors preserve preferences on both clients. | Exercise the reported problem on signed physical iPhones and staging; finish browser offline startup and remaining reminder behavior; widen migration, locale, and accessibility coverage. |
   | Sessions               | Native and browser rotation, revocation, persisted legacy-upgrade/refresh operations, concurrent-tab recovery and stale-response guards. Browser bootstrap resolves account setup before routing; saved copies and the production app shell support offline reload.                | Device/session controls, recovery email flows, deployed browser validation, storage migrations and complete account lifecycle.                                                             |
   | Barcodes               | Checked GTIN/UPC-E identities, typed results, provider budgets, user overrides, nutrient units, scanner cleanup, manual fallback, selected meal/date propagation.                                                                                                                  | Actual package detection, representative catalog fixtures, live provider access and region tests, full search-status handling, and latency measurements.                                   |
   | Offline data           | Account-scoped native cache/queue and browser drafts, immutable operations, reviewed food/measurement conflicts, deletion/restore and diary-status synchronization. Water, weight, activity and manual sleep now pass shared-client recovery checks.                               | Complete recipes, saved meals, structured workouts and sleep interval/import coverage; widen legacy-data migrations and offline browser reads.                                             |
   | Nutrition program      | Initial targets, historical target versions, fresh-measurement requirements, and explicit complete-day coverage.                                                                                                                                                                   | Complete check-in review/hold UX and enable adaptive advice only after its product and domain-review gates. Bootstrap currently exposes an explicit adaptive-nutrition flag.               |
   | Mobile UI              | Working diary, food library, setup review, program, measurement screens, and compact-phone evidence.                                                                                                                                                                               | Consistent four-destination navigation, complete recipe and saved-meal workflows, theme/accessibility work, and clearer information density.                                               |
   | Training               | Generic activity logging and existing exercise/template material.                                                                                                                                                                                                                  | Structured routines, live sets/reps sessions, rest timers, supersets, recovery, personal records, and web parity.                                                                          |
   | Health and progress    | Server-backed body measurements with offline edits, reviewed conflicts, explicit legacy imports, and export. Local reminder scheduling, device delivery controls, and a simulator-delivered notification are implemented.                                                          | HealthKit imports, quiet hours and notification deep links, physical permission checks, sleep reconciliation, private photo backup, and weekly reports.                                    |
   | AI                     | Existing coach route and saved-plan records; bootstrap advertises AI as disabled.                                                                                                                                                                                                  | Enforce flags across UI and API, replace unsupported model configuration, remove production mock fallback, ground context in logs, and create real records when a plan is applied.         |
   | Build and operations   | Native test targets, shared scheme, CI jobs for iOS/browser/Mongo tests, and a release SDK check.                                                                                                                                                                                  | Execute remote checks, establish staging, verify branch protection, instrument production, and rehearse restore/deletion/rollback.                                                         |

   Passing simulator recovery tests does not establish that the user's reported device problem is resolved. The first acceptance batch should reproduce setup on a physical iPhone with the exact app build, network conditions, and API environment recorded. Add a privacy-conscious diagnostic copy action with app version, OS version, operation/request ID, and connection state, without recording body measurements or credentials.

   A subsequent [account-calendar audit](production-evidence/calendar-audit.md) reproduced a date mismatch between the saved account zone and the browser zone. The [browser fix](production-evidence/calendar-browser.md) now uses the account day and preserves selected dates and queued operations through time-zone changes. The [native fix and shared-account verification](production-evidence/calendar-native.md) now cover native formatting, pickers and reviewed legacy imports. Broader calendar boundaries and HealthKit dates remain acceptance work.

   The barcode corpus currently includes 100 synthetic identities. That proves normalization cases, not 100 real product matches or reliable camera detection. Keep those claims separate.

   Apple's published upload requirement is Xcode 26 or later with a platform 26 SDK, effective April 28, 2026. The CI configuration names Xcode 26.2, but a configured job is not evidence that it ran successfully. See [Apple's SDK requirements](https://developer.apple.com/news/upcoming-requirements/).

   The coach route still names `gemini-2.0-flash-lite`, whose published shutdown date is June 1, 2026. Verify the replacement's account availability and behavior in staging before enabling coaching. See [Google's model lifecycle documentation](https://ai.google.dev/gemini-api/docs/deprecations).

2. **Define the product and release boundaries.** The primary user is an adult tracking nutrition and strength training on an iPhone, with the web app providing the same account data and core editing capabilities.

   Keep native SwiftUI, the current React web app, and the shared Node API. Android is a later product release. Keep iOS 17 as the provisional minimum until the upgraded toolchain and dependency audit establish the supported matrix. US English and US food coverage are the initial explicit test market; support metric and imperial units throughout, with data structures ready for more regions.

   The first public release should complete the daily loop: set up an account, receive usable targets, log food and workouts, see progress, and review the week. It must also support recovery, deletion, export, offline logging, and all exposed existing features.

   The next release adds meal planning, grocery lists, reviewed label capture, voice entry, deeper nutrition analysis, and Apple platform conveniences. More features should enter the public app only after their complete workflow passes its gate.

   Official competitor documentation supports the following priorities. These are product references, not a commitment to reproduce competitors' algorithms or interfaces.

   | Reference                                                                                                                                                                                    | Relevant behavior                                                                                                          | Exerly decision                                                                                                         |
   | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
   | [MacroFactor coaching documentation](https://help.macrofactorapp.com/en/articles/110-how-frequently-do-i-need-to-log-my-nutrition-for-the-expenditure-algorithm-and-weekly-coaching-updates) | Nutrition and weight history inform expenditure; insufficient logging can pause updates.                                   | Harden the existing adaptive engine and explain when it holds its estimate.                                             |
   | [MyFitnessPal's feature comparison](https://support.myfitnesspal.com/hc/en-us/articles/34889191368077-The-difference-between-Free-Premium-and-Premium)                                       | Food logging, barcode and meal scanning, goal controls, meal planning, and grocery tools.                                  | Make basic logging fast first. Add planning and assisted entry after food data and portions are dependable.             |
   | [Cronometer meals and recipes](https://cronometer.com/features/custom-meals-and-recipes.html)                                                                                                | Reusable meals and recipes with nutrition analysis and recipe importing.                                                   | Build proper recipe and saved-meal screens on the API work already present.                                             |
   | [Hevy's feature list](https://www.hevyapp.com/features/)                                                                                                                                     | Sets and reps, previous values, rest timers, supersets, RPE, personal records, progress charts, and platform conveniences. | Add a complete strength-training session workflow. Generic activity duration logging is insufficient for this use case. |

   The distinctive Exerly feature should be a useful weekly review combining nutrition adherence, weight trend, completed training, and sleep. Every observation should link back to the entries that support it. Users should be able to correct those entries and see the review update.

   Public social feeds, challenges, coach marketplaces, Android, and subscriptions are separate later initiatives. Remove unfinished social entry points from release navigation until they have a real backend and support process. The existing placeholder methods that return success must never represent completed user actions.

3. **Finish setup reliability before expanding the interface.** Keep app startup and onboarding in explicit states, persist inputs, and use one authoritative completion operation.

   Use a startup coordinator with the following behavior:

   ```mermaid
   flowchart TD
     A[Launch] --> B[Open and migrate local storage]
     B --> C{Saved session?}
     C -->|No| D[Welcome and sign in]
     C -->|Yes| E[Load cached account and validate session]
     E -->|Temporary network failure| F[Cached app or saved setup with retry]
     E -->|Invalid session after refresh| D
     E -->|Valid session| G{Setup complete on server?}
     G -->|No| H[Resume saved answers]
     H --> I[Validate and save setup]
     I -->|Retryable failure| H
     I -->|Confirmed complete| J[Today with initialized targets]
     G -->|Yes| J
   ```

   If storage cannot open, preserve the original store and show recovery instructions. Never silently reset the database. If there is no cached account and the network is unavailable, show a bounded connection error rather than treating the person as a new user.

   The six-screen account/setup flow, native and browser drafts, unit conversion, and completion recovery are implemented. Both clients now have durable post-setup preference editors with reviewed conflicts. Local iPhone reminder delivery uses saved intent, times, weekdays and time zones with a separate device switch. Preserve these foundations, finish the remaining reminder behavior, test real-device and staging transitions, and keep previously entered optional answers through upgrades. The requirements below are invariants to verify, not a request to recreate the working implementation.

   Behavior to preserve and complete:

   - Maintain a versioned `OnboardingDraft`, scoped to stable account ID. Save answers after edits and navigation, including backward navigation. Persist submitted values, not only the page index.
   - Validate navigation centrally. Paging gestures must not bypass required fields. Restore to the earliest incomplete required screen when a saved draft is invalid or from an older version.
   - Store kilograms and centimeters once. Convert text input and display at the boundary. Support exact numeric entry and locale decimal separators instead of forcing sliders for body measurements.
   - Separate a fitness intention such as endurance or general health from the nutrition goal of losing, maintaining, or gaining weight. Separate gender identity from any physiological parameter required by a chosen estimate, with an explained alternative or manual target flow.
   - Persist diet preferences, allergies, meal count, sleep preferences, training experience, available equipment, workout schedule, timezone, and display units wherever they are collected. A question that does not affect anything should be removed.
   - Keep completion an idempotent server operation. Validate the full payload, save the profile and preferences, seed the initial weight, initialize the program and current goals, and mark onboarding complete only when the required records agree.
   - Preserve atomic multi-record writes in both database drivers. Test rollback and concurrent submissions. Keep optional generated workouts, AI responses, permissions, and reminders outside the completion transaction.
   - Return the initialized account and target summary in the completion response. Do not require a second network request to decide whether the user can enter the app.
   - Use the setup status read to resolve a lost acknowledgement. If the server committed but the response was lost, reopening the app must discover the completed setup and avoid repeating its writes.
   - Use the server's nutrition calculation for the final review and saved result. If an offline preview is shown, label it as a preview and reconcile it before completion.
   - Save immediately after validation. Disable repeated submission while saving, allow retry after failure, and keep answers intact.
   - Ask for camera, notifications, and HealthKit access at the action that needs them. Denial must leave manual logging available. Persist reminder intent separately from the OS permission result.

   Repair existing accounts as well. Identify accounts marked complete with missing targets or programs. Derive a repair from explicit saved preferences, preserve manually edited programs, and log the migration version. If essential information is missing, show a short completion screen rather than inventing answers or rerunning all onboarding.

   Acceptance includes force-quitting at every screen, changing units repeatedly, switching accounts, losing connection during final save, losing the successful response, double-tapping Finish, expired credentials, database failure, and relaunching an older draft. Every successful setup must produce the same goal and targets in Today, Program, Profile, and web.

4. **Make the mobile interface reflect what people do each day.** Keep the existing dark palette and violet identity, but use clearer hierarchy, quieter surfaces, larger input targets, and consistent navigation.

   The compact-phone captures show that summaries, context statistics, and logging-status explanations can occupy most of the first screen before meal actions appear. Prototype a compact summary and a shorter status row with an explanation control. Measure time and taps to log a meal, rather than judging the redesign only from a large-phone screenshot.

   Use four main destinations:

   | Destination | Primary job                      | Key contents                                                                                                                 |
   | ----------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
   | Today       | Log and review the selected day. | Date navigation, calorie and macro summary, meal sections, quick water and weight entry, next workout, weekly review prompt. |
   | Food        | Find and reuse food.             | Search, scan, recents, favorites, custom foods, meals, recipes, and later meal planning.                                     |
   | Train       | Complete a training session.     | Current workout, routine schedule, exercise library, previous performance, and workout history.                              |
   | Progress    | Understand change over time.     | Weight trend, nutrition program, training progress, measurements, photos, and weekly reports.                                |

   Put Profile and settings behind a consistent header control. Make Coach available from contextual actions and a stable secondary entry. Prefer a real tab container with preserved per-tab navigation. Keep quick-add as an action with an accessible label instead of an empty middle tab.

   Screen-level changes:

   - Today opens on the current day, preserves an intentionally selected day during a logging flow, and distinguishes consumed, target, and remaining values. Show a clear "targets not configured" state instead of plausible defaults.
   - Food search opens with recents and favorites. Keep search, scanner, manual entry, and create-food routes available from the same flow. The chosen date and meal follow every route.
   - Food detail shows exact quantity, serving basis, source, and editable nutrition before logging. Support editing an existing diary item through the same controls.
   - Progress explains chart ranges, missing readings, and confidence. Provide accessible text summaries and a data table alternative for charts.
   - Distinguish nutrient minimums, limits, and target ranges. The reference diary turns every over-target macro bar amber; exceeding a protein or fiber minimum should not automatically read as failure.
   - Lead the Program screen with accepted targets and the next useful action. Put raw calculation details behind an explanation control, and label expenditure as an estimate derived from logs rather than a direct measurement.
   - Forms have appropriate keyboards, visible units, inline validation, a clear keyboard dismissal action, and a save control that remains reachable on small phones.
   - Every screen has defined initial loading, empty, loaded, refreshing, offline, stale, submitting, and error behavior. Refreshing must not erase already useful content.

   Consolidate spacing, typography, surfaces, semantic colors, buttons, fields, rows, sheets, banners, and numeric formatting into the existing design system. Use tabular figures for changing numbers. Support Dynamic Type, VoiceOver, reduced motion, increased contrast, 44-point minimum action targets, and system light/dark preferences. Avoid using color alone to distinguish nutrition states or achievements.

   Validate the smallest supported iPhone, a large iPhone, keyboard-open layouts, long food names, empty and large diaries, all supported text sizes, and iPad layouts if the app continues to declare iPad support. Capture and review real screenshots from implemented screens. A design specification or simulator build is not a visual review.

5. **Treat barcode scanning as a complete logging workflow.** Camera detection, provider lookup, nutrition conversion, and saving each need their own result and recovery path.

   The current implementation already covers most identity, camera-lifecycle, and typed-outcome requirements below. The next work is proving those paths with actual packages and providers, resolving full search-status behavior, and measuring regional coverage. Reuse the current scanner and provider adapters.

   Camera work:

   - Move capture configuration, start, and stop onto a dedicated serialized execution context. Check supported inputs, outputs, and metadata types before using them.
   - Stop the session and torch when the scanner closes or backgrounds. Resume after interruptions and recheck authorization when returning from Settings.
   - Match the scan region to the visible frame. Provide focus guidance, tap-to-focus where supported, torch feedback, and one haptic per accepted code.
   - Prevent overlapping lookups, cancel work after dismissal, and allow a deliberate rescan of the same item.
   - Provide manual barcode entry, text search, and create-food actions when scanning is unavailable, including on the simulator.

   Barcode identity work:

   - Send the raw code and detected symbology to the API. Keep barcodes as strings so leading zeros survive.
   - Normalize UPC-A, EAN-13, EAN-8, and UPC-E using tested rules and check digits. UPC-E requires expansion, not left-padding. Do not guess whether an eight-digit input is UPC-E or EAN-8 without format information.
   - Use one internal identity with provider-specific formatting and documented aliases. Preserve packaging-level distinctions in GTIN-14; do not truncate them into an unrelated retail product.
   - Return a clear unsupported-format result for arbitrary Code 128 or other non-product codes. Supporting a camera symbology does not mean a food provider accepts every value it contains.

   Apple documents that UPC-A detection appears as EAN-13 with a leading zero. FatSecret requires GTIN-13 input and explicitly requires expanding UPC-E to UPC-A first. Keep the current normalization regressions aligned with these contracts. See [Apple's detection note](https://developer.apple.com/library/archive/technotes/tn2325/_index.html) and [FatSecret's barcode contract](https://platform.fatsecret.com/docs/v2/food.find_id_for_barcode).

   Provider and nutrition work:

   - Resolve a user's barcode override or saved custom product first, then permitted cached provider records, then live providers. Preserve origin, fetch time, region, and the selected serving.
   - Verify the actual FatSecret account entitlement, OAuth scope, region coverage, and permitted storage before relying on it. An absent provider configuration is an operational state, not a product miss.
   - Replace the legacy Open Food Facts integration with its supported documented contract. Send the required app identification, implement an aggregate provider rate budget, cache repeated queries, and honor backoff. Remote Open Food Facts search should not run on every keystroke.
   - Keep autocomplete within local recents and favorites, then submit or deliberately debounce remote search according to the provider's limits. At larger scale, choose an appropriate licensed provider or permitted local dataset rather than exceeding a shared server IP's quota.
   - Distinguish `found`, `not_found`, `invalid_code`, `unsupported_format`, `temporarily_unavailable`, and rate-limited outcomes. Authentication errors remain authentication errors.
   - Use a total lookup deadline, bounded provider timeouts, and stale cached results when permitted. Never cache an outage as "this product does not exist."
   - Preserve structured portions, including mass or volume, per-serving and per-100-unit basis, and nutrient units. A drink's per-100-ml data must not be relabeled as per-100-g data. Do not infer a grams-to-milliliters conversion without density information.
   - Keep unknown nutrients distinct from zero. Display source and missing fields; let users correct a product into their own library without silently editing shared provider data.
   - A product miss offers manual creation with the scanned code prefilled. The next scan should find that personal entry. Any public contribution is a separate explicit action.

   Open Food Facts documents API versions, identification, quotas, data quality limits, and reuse terms. Keep provider data provenance separate while reviewing caching and redistribution obligations. See [Open Food Facts integration guidance](https://openfoodfacts.github.io/openfoodfacts-server/api/) and [barcode normalization](https://openfoodfacts.github.io/openfoodfacts-server/api/ref-barcode-normalization/).

   Assemble at least 100 representative product cases, with recorded provider fixtures and a smaller physical-package camera set. Cover leading-zero UPCs, UPC-E expansion cases, EAN-8/13, unsupported codes, damaged labels, glare, low light, missing nutrients, different portions, 429s, timeouts, and no connectivity. Run most tests against fixtures so CI does not consume live provider quotas. Test detection success separately from catalog coverage. A correctly decoded product can still be absent from a database.

6. **Finish nutrition logging and add features that reduce daily effort.** Existing endpoints should become complete mobile workflows before adding more ways to enter the same unreliable data.

   September 22 implementation update: the browser now has one food diary flow with durable account/API-owned drafts and operations, automatic replay, conflict review, delete/restore, date/meal moves and batch copies. Fractions and weight/volume portions retain their original nutrition and entered quantity. Native fractional nutrition and correction paths pass on larger and compact iPhones. See [food recovery evidence](production-evidence/food-recovery.md). Native quantity-entry expansion, complete library workflows, recipes, saved meals and portability still need work; this section remains in progress.

   | Capability       | First public release                                                                                            | Following expansion                                                     |
   | ---------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
   | Diary editing    | Edit, delete with undo, move between meals/dates, copy a meal or yesterday's entries, batch-add selected foods. | Multi-day meal preparation and recurring planned meals.                 |
   | Food quantities  | Direct numeric quantities, fractions, grams/ounces, supported household portions, and calories-only quick add.  | More package and region-specific portion presets.                       |
   | Personal library | Persistent favorites, useful recents, custom foods, barcode association, pagination, and search.                | Personal ranking by recent meal context and time of day.                |
   | Recipes          | Ingredient selection, quantity editing, cooked yield, servings, nutrition totals, edit and duplicate.           | URL or text recipe import with ingredient matching and review.          |
   | Saved meals      | Named groups of reusable foods, fractional portions, and one-action logging with confirmation.                  | Weekly meal plan with recipe substitutions and a grocery list.          |
   | Nutrient detail  | Preserve fiber, sugar, sodium, and saturated fat across API, iOS, web, and exports where data exists.           | More micronutrients with coverage indicators and configurable views.    |
   | Assisted input   | Dependable barcode and manual entry.                                                                            | Label OCR first; voice entry and meal-photo estimates after validation. |
   | Data portability | Complete JSON export and CSV exports for common logs; import preview for a defined CSV format.                  | Tested adapters for specific third-party export formats.                |

   Store the nutrition snapshot used when a food was logged. Editing a library product or recipe later must not rewrite historical intake unless the user explicitly chooses to update affected entries. Record both entered quantity and the normalized basis so editing does not multiply values twice.

   Recipe yield must distinguish serving count from cooked batch weight. Account for unit conversions only when the ingredient supplies enough information. Unknown ingredients remain visibly unresolved during import. Imported or camera-derived meals are drafts until the user confirms food matches and quantities.

   Build grocery quantities from planned recipe servings, merge compatible ingredient units, and allow pantry exclusions and manual items. Planning a meal must not count as having eaten it. Logging the plan is a separate action that can reflect substitutions.

   Acceptance examples include logging 1.5 servings, changing that entry to 0.75 servings, using a per-100-g product for a 35-g portion, scaling a six-serving recipe, copying yesterday's meal, and undoing a deletion after synchronization. Totals must agree across iOS, web, and export within the documented rounding policy.

7. **Make adaptive nutrition explainable and conservative when data is incomplete.** Fresh-measurement guards, explicit diary status, and historical targets are implemented. The remaining work includes review/hold controls, clearer explanations, wider behavior tests, and the gate for enabling public adaptive advice. Preserve the corrected estimator inputs; passing synthetic tests alone does not validate every recommendation.

   Add actual weigh-in count, measurement recency, coverage, and explicit daily logging status to the calculation inputs. Carrying a trend forward for display must not count as new measurement evidence. A day containing one snack must not automatically count as a complete intake day.

   Support `in_progress`, `complete`, `estimated`, and `excluded` daily logging states, with a simple user-facing way to mark the day complete or explain a gap. Never treat missing intake as zero. Document how each state affects the estimator and show why an update is being held.

   Keep initial formula estimates, observed-data estimates, and user-selected targets distinct. Review nutrition bounds and supported populations with a qualified professional before enabling automated weight-loss advice publicly. The initial release should target adults; do not simply retain the current age-13 validation and assume all target calculations are appropriate.

   Keep automatic calorie adjustments stable between check-ins. Add a preview of proposed changes, an explanation of the data window, accept or hold controls, and a manual-target mode. Guard large changes and use fresh data requirements. Avoid adding wearable exercise calories again when the adaptive estimate already reflects expenditure.

   Persist target versions and effective dates. Looking at last month's diary should show the target that applied then, not silently compare it with today's target. A backdated correction can affect a future estimate, but must not rewrite the historical record of an accepted check-in.

   Required tests include the single-old-weigh-in reproduction, long logging gaps, partial days, sudden water-weight changes, maintenance, gain, loss, changing units, sparse measurements, travel, incorrect extreme entries, and corrections to earlier dates. Run simulation tests and human review of outputs; do not claim equivalence to MacroFactor's proprietary algorithm.

8. **Add a real workout tracker.** This is the largest new daily-use feature and deserves a proper data model before expanding the exercise screens.

   Distinguish a routine template from an in-progress workout and a completed session. Preserve the current generic activity logger for walks, cycling, sports, and other duration-based entries.

   The first workout release includes:

   - A searchable exercise catalog with equipment, movement type, muscle groups, instructions, and media that Exerly has permission to use. Allow custom exercises.
   - Routines that support exercise ordering, planned sets, rep ranges, rest periods, and days of the week.
   - A session screen showing previous performance alongside editable load, reps, duration, distance, and optional RPE or reps in reserve, as appropriate to the exercise.
   - Warm-up, working, drop, and failure set labels; supersets; exercise notes; substitutions; and exercise reordering.
   - Rest timers that use an absolute end time so backgrounding and app termination do not reset the clock. Notification denial must not stop the session.
   - Autosave after every meaningful edit, recovery after a crash or restart, offline completion, and duplicate-safe synchronization.
   - History, personal records with a documented calculation, volume by exercise and muscle group, and routine consistency.
   - Equipment-aware starter programs and progression suggestions that the user can inspect and accept. Changing a template does not rewrite completed sessions.

   Store structured exercises and sets, not arbitrary unchecked JSON as the only contract. Separate load units from the canonical stored value. Validate nested structures, cap payload sizes, retain stable exercise identities, and record session timezone and timestamps.

   Completion should create one session and at most one associated HealthKit workout. Repeatedly retrying Finish must return the same result. Deleting or editing a completed session must also reconcile the associated export or synchronization record.

   A meaningful acceptance session includes multiple exercises, warm-ups, a superset, a substitution, a timer that crosses backgrounding, and a network interruption. Finish it offline, reopen the app, reconnect, then verify the same session and sets on web.

9. **Complete health integration, progress tracking, and reminders.** Body-measurement synchronization, reviewed conflicts, and selected legacy-record imports already have cross-client evidence. Build HealthKit, reminders, photos, and weekly reports around that implementation. These additions need ownership and synchronization rules, not just permission switches.

   Start HealthKit integration with body mass, steps, active energy, workouts, and sleep. Request only the relevant types when the user enables a capability. Add and verify entitlements in signed builds, including background delivery only where used.

   Track source sample IDs, source applications, timestamps, and synchronization cursors. Import incrementally, handle deleted samples, and prevent imported data from being written back as a new duplicate. Define source precedence for multiple scales, phones, and watches. Weight currently has one canonical entry per day, so specify which imported reading becomes that entry and preserve manual overrides.

   Show last successful synchronization and explain unavailable data without claiming the user denied access merely because no samples were returned. HealthKit's read privacy model does not expose a simple universal read-permission flag; consult and test the [HealthKit authorization behavior](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data).

   Expand progress tracking with synced body measurements, date filtering, comparison charts, and private progress photos. Photo backup is opt-in, uses private object storage and short-lived access URLs, strips unnecessary metadata, and supports deletion from every copy controlled by Exerly. Local-only photos remain a supported choice. Export coverage must state whether media is included.

   Sleep supports manual and imported entries, overnight sessions, naps, overlaps, and daylight-saving transitions. Water uses real volumes, configurable quick-add amounts, and correction or undo. Choose one day-allocation policy for overnight sleep and document it consistently on both clients.

   Reminder preferences should create, reschedule, and cancel real notifications. Support quiet hours, weekday schedules, timezone changes, and deep links to the intended action. A disabled reminder must cancel pending notifications. Habit streaks should reward chosen behaviors and recover gracefully after breaks; avoid awarding calorie restriction or exercising through injury.

   Add weekly reports that combine completed logs and training, with explicit gaps. Show associations such as a change in sleep alongside training performance without presenting a correlation as a diagnosis or causal explanation.

10. **Make the AI coach useful and testable.** Repair the existing feature before extending it into voice or image entry.

    Replace the hardcoded model dependency that is past its published shutdown date with a configured, supported model and a documented upgrade check. Keep mock responses behind an explicit local/test setting. A production outage should show an unavailable state while the rest of Exerly continues to work.

    Build context from recent confirmed diary entries, actual training sessions, current target version, preferences, and measurement coverage. The current progress-analysis prompt mostly receives profile fields and targets; it needs real progress data to make a grounded comparison.

    Calculate totals and trends in application code. Let the model explain those results or propose structured changes. It must not invent logged meals, estimate missing weights as observations, or set nutrition targets outside the application's rules.

    Replace the current "applied" flag behavior with reviewable actions. A proposed workout should validate against exercise identities, available equipment, and the workout schema, then create an actual routine after user confirmation. A proposed meal should become a draft using known ingredients and portions. Replaying an accepted action must not create another copy.

    Treat user-entered food descriptions, imported recipes, and model responses as untrusted text. Sanitation alone is not protection against prompt injection. Restrict the coach to explicit allowed operations, validate structured output, and keep permission and ownership checks in the API.

    Add timeouts, cancellation, bounded output, per-account quotas, aggregate spending limits, model-version monitoring, and no double credit charge on retries. Record only the minimum diagnostics needed; do not put raw health context, prompts, or photos into general analytics.

    Explain and obtain permission before sending personal information to an external AI provider. Offer a useful app experience with AI disabled. Apple's review guidelines explicitly cover disclosure and permission for sharing personal data with third-party AI. See [App Review Guidelines, section 5.1.2](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing).

    Maintain an evaluation set covering missing history, contradictory goals, unknown foods, unsuitable equipment, out-of-scope medical questions, prompt injection, provider failure, and valid plan application. Label photo-based nutrition as an estimate and require portion review. Start label OCR on-device where feasible; use voice and meal-photo input only after the resulting drafts meet the same validation rules as manual entry.

11. **Complete durable local data and predictable synchronization.** The account-scoped SwiftData cache, persistent mutation queue, server acknowledgements, conflict review, and change feed now exist. Extend them to remaining log types and new features. The rules below must hold across the whole product, not only food, measurements, diary status, and the newest water work.

    The [browser offline startup implementation](production-evidence/browser-offline-startup.md) now persists account-scoped display reads and a production app shell. Server acknowledgements remain separate from cached displays. Automatic replay across all browser queues and the remaining write workflows still require work.

    Add stable account IDs to new data and sessions, then migrate the existing email-based ownership deliberately. Do not introduce email-change functionality until ownership no longer depends on mutable email addresses. Keep old client contracts compatible during this transition.

    Every offline mutation needs an operation UUID, account ID, entity ID, operation type, payload version, base revision, creation time, attempt count, and sync state. Save the local record and pending operation together before reporting that the entry is saved on the device.

    The server must enforce idempotency with a unique key scoped to account and operation. Reusing a key with different content must fail. Retain deduplication information for the supported offline period; a queue older than that must reconcile before replay rather than blindly resubmitting.

    Use three visible save outcomes: saved locally and pending, synchronized, or needs attention. Request cancellation and malformed responses must not be treated as an instruction to repeat a committed mutation.

    Define conflict behavior by data type:

    | Data                                       | Conflict policy                                                                                                                      |
    | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
    | New diary entries and new workout sessions | Unique operation/entity IDs make independent additions merge without duplication.                                                    |
    | Edits to an existing entry or routine      | Compare revisions; do not silently overwrite a newer edit from another device. Fetch the current value and offer a clear resolution. |
    | Deletions                                  | Use a deletion marker or equivalent change record so an offline device cannot resurrect a deleted record.                            |
    | Water increments                           | Apply identified increments once; reconcile them into a daily total. Avoid racing read-modify-write totals.                          |
    | One weight per day                         | Define manual/import precedence and surface competing manual edits; do not let replay order silently decide.                         |
    | Goals, setup completion, and check-ins     | Apply a versioned server operation with atomic updates and one authoritative result.                                                 |

    Sync on launch, foregrounding, after mutations, and when connectivity returns. Background work is opportunistic and must not be necessary to preserve an entry. Isolate one account's cache and queue from another account, cancel requests on logout, and prevent a late response from the old session populating the new account.

    Version the local database and test migrations from shipped schemas. Preserve legacy records before converting them. Records without reliable ownership must not automatically upload into whichever account happens to log in next. Provide an explicit recovery or import flow for that legacy data.

    Add a small repository layer around these concrete needs so views do not duplicate cache and retry logic. Keep the existing SwiftUI view-model pattern; avoid a wholesale architecture rewrite.

    Several contracts below now exist: bootstrap, setup drafts and completion, idempotent mutations, diary status, target history, and incremental synchronization. Review and extend their actual implementation in `docs/API.md`; the table describes the required behavior, not a list of wholly new endpoints. Workout-session, HealthKit-import, planning, and media contracts remain additions. Preserve old client compatibility during migrations.

    | Contract                             | Stored information and behavior                                                                                                                                                         |
    | ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | `GET /api/bootstrap`                 | Current account, session generation, setup status/version, accepted targets, and available feature flags. A cached response may render the app, but cannot authorize server operations. |
    | `GET/PUT /api/onboarding/draft`      | Account-scoped answers, draft revision, schema version, and last valid step. Local saving continues if the server is temporarily unreachable.                                           |
    | `POST /api/onboarding/complete`      | The atomic completion operation with an idempotency key and draft revision. Returns initialized records and supports status reconciliation after a lost response.                       |
    | `Idempotency-Key` on mutations       | Operation identity, request fingerprint, execution status, result, and retention policy. Enforce uniqueness in storage, not only in application memory.                                 |
    | Diary-day and target-version records | Logging-completeness status, notes, target effective dates, and the accepted check-in that created each target version.                                                                 |
    | Workout templates and sessions       | Separate template, session, exercise-in-session, and set identities. Session changes cannot mutate historical template versions accidentally.                                           |
    | Health import records                | Source sample ID, type, source app, observed time, import cursor, deletion status, and link to the canonical app record.                                                                |
    | Incremental synchronization          | Revision or cursor-based reads with deletions included, pagination, and entity revisions on writes. Avoid downloading the account's entire history on every launch.                     |
    | Meal plans and media records         | Planned entries remain distinct from eaten entries; private photo metadata remains separate from the image bytes and upload lifecycle.                                                  |

    Keep single-entry food writes backward compatible. Use an additive structured quantity/nutrient representation before retiring older numeric fields, and test old and new mobile clients against the same staging API.

12. **Close account and production-operation gaps.** Public readiness includes the complete account lifecycle and an API that can be operated safely.

    Preserve the implemented native session rotation and revocation. Complete modern browser credentials, device/session management, password reset with expiring single-use tokens, email verification, and password-manager-friendly forms. Migrate remaining compatibility sessions to short-lived access tokens and securely stored rotating refresh credentials. Retain the account-switch and stale-response regressions so an old response cannot erase or replace newer credentials.

    Recheck authorization against current privileges for sensitive operations rather than trusting a month-old admin claim alone. Apply account-scoped rate limits and provider budgets that work across multiple API instances. Fail clearly on missing required production configuration.

    Add in-app data export and account deletion. Deletion covers account records, refresh credentials, diary data, workouts, personal foods, AI history, uploaded media, and device caches. Track asynchronous deletion work and communicate backup-retention behavior. Apple requires apps supporting account creation to let users initiate account deletion in-app. See [Apple's deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/).

    Extend the existing measurement and JSON export work to cover every supported record type. Include a clear manifest for photos and any remaining local-only records. Add CSV import with a dry run, unit/date preview, duplicate handling, rollback by import batch, and no changes until the user commits the preview.

    Operational work includes:

    - Distinct Debug, Staging, and Release API configuration. Simulator and physical debug devices must be able to target staging or local development explicitly, instead of environment selection being determined only by simulator detection.
    - A reproducible development command, supported pinned Node and Xcode versions, example configuration, fixture providers, migration commands, and a readiness endpoint. Local development should work without paid provider keys.
    - Versioned API contracts and error codes, a minimal OpenAPI schema, and shared response fixtures checked by Swift and web decoding tests. Introduce contract checks around high-risk flows first.
    - MongoDB integration tests for unique indexes, transactions, dates, serialization, and concurrent updates. SQLite-only tests cannot prove production driver behavior.
    - Safe additive migrations, tested backfills, read compatibility during rollout, migration status, and a restore rehearsal before destructive changes.
    - Request IDs, app-version tags, crash and hang reporting, API latency/error metrics, provider metrics, sync-queue age, and privacy-conscious setup funnel events.
    - Alerts for failed setup, duplicate operations, stale queues, provider outages, elevated authorization errors, and failed deletion jobs.
    - Staging and production separation, managed secrets, bounded logs, encrypted backups, and an agreed recovery objective. Proposed initial objectives are recovery within four hours and no more than one hour of recoverable server data loss, subject to the selected backup configuration and a restore test.
    - Feature flags for unfinished capabilities, a tested API rollback, and a staged app rollout. Preserve compatibility with already installed clients during rollback.

    The current deployment specification deploys API changes from `main`. Move production changes behind the required checks and a concrete release process. Do not depend on README claims that branch protection is enabled; inspect the actual repository settings during implementation.

    Track recurring costs for food data, AI, database, backups, object storage, email, monitoring, and CI. Set quotas and alerts before inviting a wider beta. Verify licenses and account entitlements before making a vendor a critical dependency. This plan does not require purchasing a particular service.

13. **Build verification around complete user journeys.** Add tests that catch lost data and broken transitions, then measure the app under realistic conditions.

    | Layer                          | Required coverage                                                                                                                                                                       |
    | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | Swift unit tests               | Startup state transitions, draft restoration, unit conversion, barcode normalization, decoding, conflict handling, timer restoration.                                                   |
    | API unit and integration tests | Atomic setup, target initialization, idempotent writes, barcode provider outcomes, recipe portions, historical targets, ownership, sessions, deletion.                                  |
    | Both database adapters         | Transactions, uniqueness, rollback, dates, migration fixtures, concurrent writes, and serialization parity.                                                                             |
    | iOS UI tests                   | Signup to usable diary, interrupted setup recovery, log and edit food, selected-date scanning using injected results, offline workout recovery, settings, export/deletion entry points. |
    | Physical devices               | Camera focus and detection, permission changes, HealthKit, notification delivery, backgrounding, battery/thermal behavior, and signed entitlements.                                     |
    | Web/browser tests              | Account and target parity, food and workout editing, date/unit consistency, import/export, and mobile browser layouts.                                                                  |
    | Fault injection                | Timeout before write, committed write with lost response, invalid response, expired session, provider throttling, app kill during save, storage failure, interrupted migration.         |

    Retain the two regression tests added after the initial audit. One proves that onboarding a weight-loss user produces the selected program and non-null targets. The other proves that a single stale weigh-in cannot produce high confidence. Extend the native and browser suites around remaining features rather than restarting their test infrastructure.

    Proposed release targets below are targets, not measurements achieved by the current app. Establish performance baselines on named hardware and networks, then document any justified adjustment.

    | Area                      | Gate                                                                                                                                                                      |
    | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | Critical correctness      | Every critical journey passes on supported configurations. No open defect involving data loss, account leakage, duplicate writes, or inability to complete setup.         |
    | Setup recovery            | All interrupted-save, relaunch, duplicate-submit, and account-switch scenarios pass without lost answers or inconsistent completion.                                      |
    | Setup reliability         | At least 99.5% successful finalizations among valid online submissions in beta, counting recovered retries once per operation. Track abandonment separately.              |
    | Saved data                | Zero lost or duplicated acknowledged entries in fault-injection and multi-device tests. Offline entries remain available after termination.                               |
    | Startup                   | Cached usable content within two seconds at the 95th percentile on the oldest supported test device. Connection failures show a bounded recovery state.                   |
    | Interaction               | Visible response to ordinary taps within 100 ms; scrolling and set entry remain responsive during synchronization.                                                        |
    | Barcode                   | At least 95% detection on the agreed physical-package set in normal conditions. Report provider coverage independently. Every miss or outage has a working recovery path. |
    | Barcode latency           | Cached lookup within one second at the 95th percentile. Live lookup aims for three seconds on the specified test network, with a useful fallback within eight seconds.    |
    | Crash and hang monitoring | At least 99.8% crash-free sessions across a minimum of 1,000 beta sessions over at least 14 days, plus zero reproducible launch/setup crashes. Report the sample size.    |
    | Sync                      | Foreground pending entries reconcile within ten seconds of restored connectivity on the test network; permanent failures remain visible and recoverable.                  |
    | Accessibility             | Core journeys complete with VoiceOver and the largest supported text size; reduced-motion and contrast checks pass.                                                       |
    | Operations                | Staging deployment, backup restore, deletion, alert delivery, and rollback rehearsals pass. Monitor a 99.9% core API availability objective after launch.                 |

    A small beta cannot establish long-term reliability by statistics alone. Combine the sample with deterministic recovery tests, device testing, and ongoing monitoring. Provider-dependent targets are conditional on the documented provider response budget; a successful timeout recovery must not be reported as a product match.

14. **Deliver the remaining work in dependency order.** Keep the original phase numbers so the implementation ledger remains comparable. Estimates below cover remaining engineering effort after the September 22 foundations, including iOS, API, necessary web parity, and verification work.

    | Phase | Remaining scope and dependencies                                                                                                                                                                  | Remaining effort | Exit evidence                                                                                          |
    | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------ |
    | 0     | Close toolchain, remote CI, staging, environment configuration, and initial observability gaps. Native test targets already exist.                                                                | 0.5 to 1 week    | Supported release build/test artifacts, known staging environment, retained diagnostics.               |
    | 1     | Validate existing setup/session recovery on physical devices; finish browser draft/session parity, optional personalization, and broader legacy migrations. Depends on phase 0's environment.     | 0.5 to 1 week    | Reported setup problem has a reproduction and verified recovery; every client agrees on saved targets. |
    | 2     | Validate existing barcode code against actual packages and live providers; complete search outcomes and measured latency/coverage. Depends on a signed build and provider access.                 | 1 to 2 weeks     | Separate package-detection and product-lookup results, verified fallback, regional coverage report.    |
    | 3     | New navigation, complete nutrition editing/recipes/saved meals, remaining offline log types, program review controls, and data migration. Extend the existing sync engine.                        | 3 to 5 weeks     | A full nutrition week, including interruption and correction, works on iPhone and web.                 |
    | 4     | Structured training templates/sessions, sets/reps, timers, supersets, history, recovery, and web parity. Depends on phase 3's reusable sync behavior.                                             | 3 to 5 weeks     | A complete mixed online/offline workout resumes and synchronizes once, with accurate history.          |
    | 5     | HealthKit, reminders, sleep reconciliation, private photo backup, weekly reviews, and functional coaching. Measurement sync is already implemented. Depends on stable nutrition/training records. | 3 to 5 weeks     | Integrated weekly workflow passes with permissions enabled/denied and providers unavailable.           |
    | 6     | Account lifecycle, privacy, import/export completion, accessibility/device regressions, operational rehearsal, and beta fixes. Begin security work early.                                         | 2 to 4 weeks     | Public core meets every release gate; unresolved high-severity defects block release.                  |
    | 7     | Meal planning, groceries, label OCR, reviewed voice/photo drafts, deeper nutrients, widgets, Shortcuts, and Live Activities. Follows core stability.                                              | 4 to 6 weeks     | Each new workflow has complete save/edit/recovery behavior and an independent rollout flag.            |

    Remaining public-core effort is approximately 13 to 23 engineering weeks for one experienced engineer with periodic design, QA, and domain review. The fuller expansion is approximately 17 to 29 weeks. These ranges replace the original whole-project estimate of 18 to 28 weeks for the core; completed foundations must not be counted again.

    Reserve 20 to 30 percent for integration findings, device-specific issues, and beta fixes. Add a minimum two-week beta observation period, which can overlap late hardening. Estimates assume access to signing, staging, provider entitlements, and test devices; waiting for access or external review extends calendar time. Re-estimate after closing phases 0 through 2 using measured remaining issues.

    An Apple Watch workout companion is a separate 3 to 5 week follow-up after phone/watch synchronization and standalone versus companion scope are designed. Android, public social features, and subscriptions remain separate initiatives.

    Stage the product as four usable releases: an accepted setup/barcode build after phases 0 through 2, a daily-use nutrition beta after phase 3, a complete public nutrition/training core after phases 4 through 6, and individually gated expansion features from phase 7. Preserve the release gates if scope changes.

15. **Start with a focused acceptance and completion batch.** The workspace already contains substantial foundation work. The next backlog should close its open gaps and establish a stable base for the product expansion.

    | Order | Next task                                                                              | Main areas                                                                           | Acceptance                                                                                                                               |
    | ----- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
    | 1     | Preserve and reconcile the current implementation baseline before release integration. | Working tree, remote changes, existing plan/status records.                          | All existing work is accounted for; no uncommitted implementation is discarded; checks refer to the actual candidate revision.           |
    | 2     | Execute the release toolchain and configured CI on a candidate revision.               | `scripts/ios.sh`, `.github/workflows/ci.yml`, Xcode/signing configuration.           | Xcode/SDK requirements pass and native, browser, and both-database results are retained.                                                 |
    | 3     | Reproduce the reported setup friction on signed physical devices and staging.          | Auth/bootstrap, six-screen setup, cloud drafts, target preview, diagnostics.         | Fresh and legacy accounts survive interruption, a lost success response, denied optional permissions, and relaunch with correct targets. |
    | 4     | Complete web setup/session parity and deferred personalization.                        | Web onboarding/auth, profile settings, draft endpoints, native settings.             | Either client resumes the same answers; reviewed conflicts preserve intent; collected preferences can be changed after setup.            |
    | 5     | Validate real barcodes and provider contracts.                                         | Scanner, food adapters, provider budget, fixture corpus.                             | Representative packages scan; live lookups preserve units; genuine misses and outages lead to a working manual/custom-food path.         |
    | 6     | Close remaining synchronization and migration gaps.                                    | SyncEngine, water/weight/activity/sleep routes, SwiftData migrations, legacy import. | Every exposed log type survives termination and replay without duplication; tests include simultaneous devices.                          |
    | 7     | Prototype and implement the revised Today/Food/Train/Progress navigation.              | Native tab shell, diary, library, progress, shared components.                       | Core actions remain reachable on the smallest supported phone and at large text sizes; per-tab state persists.                           |
    | 8     | Finish recipe, saved-meal, and batch diary workflows.                                  | Library API, iOS food screens, web diary.                                            | A home-cooked recipe can be created, portioned, edited, reused, and exported without rewriting older intake.                             |
    | 9     | Add structured workout sessions and recovery.                                          | Workout contracts, templates, active-session UI, sync.                               | A realistic workout resumes after backgrounding/termination and produces one consistent history record on both clients.                  |
    | 10    | Close account, operational, and public-release gates.                                  | Recovery/deletion/export, monitoring, backup/restore, accessibility, beta.           | Every advertised feature works through errors and recovery; required operational rehearsals and observation evidence exist.              |

    Each implementation batch should update the existing status ledger with the exact change, test command, result, evidence path, remaining limitations, and next task. A feature has four distinguishable states: implemented, automated checks passed, real-device/provider checks passed where applicable, and public-release accepted.

    This refresh produced an updated plan, not additional application changes. The current code builds and its 122 SQLite API tests pass. Several core flows have prior simulator evidence, but the physical-device, provider, release-toolchain, operational, and beta gates remain open.
