# Exerly release readiness

Updated 2026-10-07. Internal TestFlight is authorized. External TestFlight and App
Review require Ali's decision after the build and review material are ready.

## Current build

U.S. portion milestone A10, version 1.0 build 2610071410, is available in
internal TestFlight. Apple reports VALID and IN_BETA_TESTING. The Ali-only
group contains exactly this build, with the English notes verified. Availability
was verified at 10:22 EDT on 2026-10-07. The phone needs Tailscale for devbox1
staging and the existing internal account.

New U.S. food portions default to ounces, or fluid ounces when a food has a
recorded density. Switching between ounces, grams, fluid ounces, milliliters and
named servings preserves exact weight and nutrients. Saved measures survive
offline logging and relaunch. Explicit metric preferences remain metric.
Estimated density is labeled and selected portion presets have a checkmark.
Calories remain kcal, macros grams, body measurements pounds and feet/inches,
and water U.S. fluid ounces by default.

A9's staged entry nutrient corrections and scrolling fix are included. A8's
original purple/pink identity, dark default, pulse logo and summary hierarchy
remain. Nutrition label scanning is being tested separately and is not included.

The complete fixed-source A10 gate passed175 active hosted tests and44 UI
journeys, plus one credential skip and nine documented opt-in/cross-client UI
skips. All53 UI methods ran exactly once. After rebasing onto Logic's progression
update, Core305, API260, full175 hosted tests, device build and both affected
planned-workout/program-builder journeys passed. App and UI test sources were
identical across that rebase. Evidence is artifacts/nutrition/a10-verified-manifest.json
in the release worktree. Portion checks also pass at default light/dark and
largest type, including offline relaunch and exact exported weight checks.

Fresh primary light/dark captures and portion review are in
artifacts/design/a10-primary-_, a10-verified-3 and portion-_-final-ax in the primary
worktree. Every primary capture was reviewed alongside the public App Store
references. The portion comparison is contact-review/a10-portions-reference.png.
The gallery is http://100.80.149.7:39215. Physical installation, Apple sign-in,
Health authorization, VoiceOver and measured phone performance remain unverified.
Full feature parity is open.

Signed archive and IPA checks passed identity, entitlements, profile, privacy
manifest, icon, version, staging endpoint and absence of debug hooks.

- Release worktree: `/Users/aldo/Desktop/Exerly-Fitness-app-programs`.
- Archive: `apps/ios/build/release/2610071410/Exerly.xcarchive`.
- IPA: `apps/ios/build/release/2610071410/export/Exerly.ipa`.
- Logs: `apps/ios/build/release/2610071410/{archive,export,upload}.log`.
- Build and delivery UUID: `4b0598ef-61f7-469b-96c7-1f76ac5724b5`.
- Fixed source tag: `ios/internal-2610071410`, commit79d4c213.
- Bundle: `com.exerly.fitness`, Apple bundle resource `UJ5X8TJKNL`.
- Team: `9X79V37Q89`. Distribution certificate expires2027-09-25.
- Exerly profile: `J5J395Y9AF`, HealthKit and Apple sign-in, same expiry.
- App Store Connect: Exerly, app ID `6819776832`.
- Internal group: `Exerly Internal · Ali`, `c5ae1d39-0fe4-4bee-af89-0374d9519afe`.
  Only Ali, no public link or automatic future builds.
- Availability evidence: `artifacts/nutrition/a10-internal-2610071410.json`.
- Exact test notes: `docs/release/a10-internal-notes.txt`.

A9 build2610071223 was detached only after1410 became available. No other app's
identifiers or profiles changed. Credentials stay outside the repository.

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
| Internal TestFlight upload        | Available internally  | 1.0 (2610071410), valid and in beta testing; only Ali and only this build.                                                                             |
| Feature parity                    | Open                  | Every PARITY.md row must have device evidence.                                                                                                         |
| Beyond                            | Open                  | Ship and measure B01-B12; no unproven superiority claims.                                                                                              |
| Native test suite                 | In progress           | A10: API260, Core305,175 hosted and44 active UI pass, plus focused light/dark/AX checks. Device build passes.                                          |
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
