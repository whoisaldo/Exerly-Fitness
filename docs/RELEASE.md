# Exerly release readiness

Updated 2026-10-07. Internal TestFlight is authorized. External TestFlight and App
Review require Ali's decision after the build and review material are ready.

## Current build

Design milestone A8, version1.0 build2610071054, is available in internal
TestFlight. Apple reports VALID and IN_BETA_TESTING. The Ali-only group contains
exactly this build, with the English design-change notes verified. Uploaded at
06:59:22EDT and internal availability verified07:03EDT on2026-10-07. The phone
needs Tailscale for devbox1 staging. The private internal account signs in
successfully. Original purple/pink, dark default and E/pulse mark remain.

A8 gives existing screens one design system, summary-first diary and training,
clear next actions and empty states, shared numeric controls, target progress,
compact program previews and prominent suggestion changes. Account export has
one route with an offline choice. Sync reflects both stores and clears stale
status. Health requests only the two displayed read types and keeps its reading
preference separate by account. The final accessibility review fixed wrapping
fields, program menus, keyboard dismissal and oversized decorative icons.

New accounts default to U.S. units: nutritional Calories, pounds, feet/inches,
and fluid ounces for water. Explicit metric choices stay metric. Macro amounts
remain grams. Food ounce/volume entry, entry nutrient corrections, plates and
recipes are the next nutrition work; they are not claimed in this release.

The fixed5b2c9f92 baseline passed167 active hosted tests and40 active UI journeys,
with one private-credential skip and nine opt-in/cross-client UI skips. Core300,
API260, device build and repository hooks pass. The final5e351cc8 source adds
verified program choices and AX wrapping corrections. Affected checks passed:
program builder/lifecycle at default size, full program builder at largest type,
agent creation/revocation/direct-write consent at largest type, offline export
and reconnection, empty/secondary screens, and fresh default light/dark/AX primary
captures. The real native reminder banner was also captured. Detailed counts,
source boundaries and earlier failed runs remain in docs/ledger/app.md.

The final comparisons against public MacroFactor, Workouts, Things and Fitness
screenshots are in artifacts/design/contact-review/final-*.png. Original native
images and169 named view variants are browsable at http://100.80.149.7:39215.
Physical installation, Apple sign-in, Health authorization, VoiceOver and measured
phone performance remain unverified. Feature parity is not complete.

Signed archive/IPA checks pass for identity, HealthKit and Apple sign-in
entitlements, profile, privacy manifest, icon, version, staging endpoint and
absence of debug hooks. Source is fixed5e351cc8 in the single release worktree.

- Release worktree: `/Users/aldo/Desktop/Exerly-Fitness-app-programs`.
- Archive: `apps/ios/build/release/2610071054/Exerly.xcarchive`.
- IPA: `apps/ios/build/release/2610071054/export/Exerly.ipa`.
- Logs: `apps/ios/build/release/2610071054/{archive,export,upload}.log`.
- Build UUID: `2369b3ca-bb37-40f7-b0c0-b83831fa2d40`.
- Bundle: `com.exerly.fitness`, Apple bundle resource `UJ5X8TJKNL`.
- Team: `9X79V37Q89`. Distribution certificate expires2027-09-25.
- Exerly profile: `J5J395Y9AF`, expires2027-09-25, HealthKit and Apple sign-in.
- App Store Connect: Exerly, app ID `6819776832`.
- Internal group: `Exerly Internal · Ali`, `c5ae1d39-0fe4-4bee-af89-0374d9519afe`.
  Only Ali, no public link or automatic future builds.

A6 build2610070024 was detached only after1054 became available. Obsolete signed
candidates0818/0937/1041/1049 were never uploaded. Credentials and signing material
stay outside the repository. No other app's identifiers or profiles changed.

## Repeatable commands

From the repository root:

```sh
python3 -m unittest discover -s apps/ios/scripts/tests
node --test apps/ios/scripts/tests/asc.test.mjs
node apps/ios/scripts/asc.mjs provision
bash apps/ios/scripts/release.sh --dry-run
bash apps/ios/scripts/release.sh --archive
bash apps/ios/scripts/release.sh --upload
node apps/ios/scripts/asc.mjs status
node apps/ios/scripts/asc.mjs internal BUILD_NUMBER
```

Use a new UTC timestamp for each archive. `BUILD` can override the default
`yymmddHHMM`. The script refuses to overwrite an archive. Internal builds default to staging
(http://100.80.149.7:39110). EXERLY_RELEASE_ENVIRONMENT=production chooses public
HTTPS only after its API supports the native session protocol. Staging validation
allows only the exact authorized address and explicit staging metadata. Signed modes use a
temporary keychain, restore the prior keychain list and remove only the profile
they installed. `--archive` produces a signed IPA without an upload. `--upload`
exports for internal testing only, checks that the app record exists, then uploads.
Run `internal BUILD_NUMBER` only after Apple reports the build as valid. It checks
that the existing tester is Ali and internal, and that the group has no public
link, no other members and no automatic access to future builds.

The [initial app record][apps] and Ali's membership in the internal group were
created through Apple's website. API checks verify the group and account-holder
email before assigning a build. Apple's [inviteType][invite] describes email
versus a public link; internal status comes from the group's isInternalGroup.
Manual profile selection is scoped to the app target so Swift package resource
bundles are not given an unsupported provisioning profile.

## App Store checklist

| Item                              | State                 | Acceptance and next action                                                                                                                             |
| --------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Bundle registration               | Done                  | Only com.exerly.fitness registered; HealthKit and Apple sign-in enabled.                                                                               |
| Distribution signing              | Done                  | Existing certificate reused; signed archive and export verified.                                                                                       |
| App icon                          | Built                 | Established purple E/pulse mark, opaque 1024px; replaces the rejected mint monogram.                                                                   |
| App Store Connect record          | Done                  | Exerly created, app ID 6819776832.                                                                                                                     |
| Internal group                    | Done                  | Exerly Internal · Ali; only account-holder Ali, no public link, explicit builds.                                                                       |
| Internal TestFlight upload        | Available internally  | 1.0 (2610071054), valid and in beta testing; only Ali and only this build.                                                                             |
| Feature parity                    | Open                  | Every PARITY.md row must have device evidence.                                                                                                         |
| Beyond                            | Open                  | Ship and measure B01-B12; no unproven superiority claims.                                                                                              |
| Native test suite                 | In progress           | A8: API260, Core300,167 hosted and40 active UI pass, plus focused final deltas. Device build passes.                                                   |
| Light/dark and Dynamic Type       | Open                  | Inspect all major flows at largest text on small/large phones.                                                                                         |
| VoiceOver/contrast/reduced motion | Open                  | Device audit, accessible form errors and charts, no clipped controls.                                                                                  |
| Performance                       | Open                  | Cold-launch measurements and 60 fps scrolling traces on a physical phone.                                                                              |
| Offline and conflict behavior     | Partial               | Existing queue tests pass; every new domain needs equivalent device journeys.                                                                          |
| Sign in with Apple                | Built                 | Native nonce/state/token flow and Core bridge tests pass; physical authorization remains.                                                              |
| Account deletion                  | Built                 | Confirmation, server deletion, lost response and local cleanup pass; physical Apple reauthorization remains.                                           |
| Export/import                     | Partial               | Full-fidelity export/import with user review and synthetic round-trip fixtures.                                                                        |
| Production database               | Blocked on deployment | Ali supplies Neon/DO secrets; logic owns migration and backups.                                                                                        |
| Privacy manifest                  | Built                 | UserDefaults reason CA92.1; account, health, fitness and user content for functionality; no tracking. Audit before submission.                         |
| Privacy labels                    | Draft                 | Match actual server/cloud handling. Do not publish until the final data-flow audit.                                                                    |
| Privacy policy                    | Open, Ali review      | Draft notice and data-flow review in docs/release; retention, production providers, legal review and hosted URL remain.                                |
| HealthKit purpose strings         | Partial               | Current Health screen requests two read types and no writes; native permission/relaunch passes. Physical authorization remains.                        |
| Cloud inference consent           | Open                  | Existing Gemini feature requires disclosure/opt-in redesign before public release.                                                                     |
| Encryption/export compliance      | Draft                 | App uses platform TLS/Keychain, no custom encryption; Info declares no non-exempt encryption. Ali reviews legal declarations before public submission. |
| Age rating                        | Open, Ali review      | Complete current questionnaire based on shipped features; no medications or medical claims.                                                            |
| Name/subtitle/description         | Draft below           | Verify lengths, actual functionality and name availability in ASC.                                                                                     |
| Keywords/category/copyright       | Draft below           | Fitness category, Sideband copyright and accurate search terms.                                                                                        |
| Screenshots                       | Open                  | Synthetic data only, final UI, all required device sizes and localizations.                                                                            |
| Support URL                       | Partial               | Exerly-specific help and deletion guidance drafted in docs/release/support-draft.md; public Sideband page remains to publish.                          |
| Review notes/test account         | Open                  | Synthetic account; explain HealthKit, permissions, offline use and account deletion. No credentials committed.                                         |
| Crash diagnostics                 | Open                  | MetricKit/TestFlight only, no third-party SDK. Document collection accurately.                                                                         |
| Two consecutive full audits       | Open                  | Zero completed clean audits.                                                                                                                           |
| External review / App Review      | Not authorized        | Prepare all material, then ask Ali.                                                                                                                    |

## Draft metadata

- Preferred name: Exerly.
- Fallback name: Exerly Training & Nutrition.
- Subtitle: Training, food and evidence.
- Primary locale: English US.
- SKU: sideband-exerly-ios.
- Primary category: Health & Fitness.
- Copyright: © Sideband.
- Support/contact: hello@sideband.studio, https://sideband.studio.
- Candidate keywords: workout,training,nutrition,macros,food,weight,strength,sets,reps,progress.

Draft description for the finished product, not the current build:

> Log training and food in one place. Record sets, meals and body measurements,
> review your progress, and keep logging when you are offline. Exerly shows the
> records behind its calculations. Agent suggestions arrive as changes you can
> review, accept or undo. Export your data or connect your own agent through scoped
> access. AI is optional.

Replace this draft with the capabilities actually verified at submission. Do not
claim full parity, superior food coverage or sub-second launch until measured.

## Internal test notes for the program build

Enable Tailscale before signing in to staging. Use synthetic data. Build a small
program, review the next workout, finish it, and check the following planned day.
Try duplicate/archive/restore and review a program proposal before deciding.
Log a barcode food to Dinner, scroll the detail screen, then edit its amount
offline and relaunch. Profile > Sync backs up account records. Physical Apple
sign-in/linking and deletion reauthorization still need testing. Report crashes
through TestFlight. The A7 replacement nutrition diary is not in this build.

[apps]: https://developer.apple.com/documentation/appstoreconnectapi/apps
[invite]: https://developer.apple.com/documentation/appstoreconnectapi/betatester/attributes-data.dictionary

## Test account and release smoke

Credentials are kept outside the repository in ~/private_keys/exerly-testflight-account.json.
The account contains synthetic onboarding only. Set TEST_RUNNER_EXERLY_ACCOUNT_SMOKE_PATH
to that file for AccountInfrastructureTests/testInternalTestAccountCompletesNativeSignInAndBootstrap.
This tests the app target’s compiled endpoint, Keychain session persistence, login and
bootstrap; it caught the difference from the stale production API. Hosted Core Keychain
replacement/isolation/accessibility/removal also passes. Neither test prints credentials.

## Prepared support and privacy material

[Support instructions](release/support-draft.md), [privacy notice](release/privacy-policy-draft.md)
and the [data-flow/publication review](release/privacy-review.md) are drafted for
Ali and Logic to review. They describe the current native routes, separate
local Health/photo use from account sync, and identify the production retention
and provider decisions still needed. Nothing has been published or submitted.

The full design pass is shipped internally as2610071054. Keep physical-device
checks and the broader parity backlog open. Resume nutrition from the ledger.
