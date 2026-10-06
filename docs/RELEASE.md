# Exerly release readiness

Updated 2026-10-06. Internal TestFlight is authorized. External TestFlight and App
Review require Ali's decision after the build and review material are ready.

## Current build

Training insights milestone A5, version 1.0 build 2610062144, is available in
internal TestFlight. Apple reports VALID and IN_BETA_TESTING. The Ali-only
internal group contains exactly this build, and its English test notes were
verified. It uses devbox1 staging, so the phone needs Tailscale. The original
purple/pink theme, dark default and E/pulse icon are preserved.

A5 adds optional checks of recently finished workouts, reviewable corrections,
training observations, completed-set logs and source workout links. Turning
entry checks off keeps manual logging available. Rejected or undone checks do
not return. Missing source data is marked as unavailable. Agent review, account
management, tokens and exports remain available. Program and nutrition proposal
types are explained before an unsupported decision.

Final validation passed 123 hosted tests and 25 UI journeys, with eight opt-in
skips and zero failures, plus API 226, Core 233 and the iOS device build. Eleven
insight hosted tests include regressions for one failed filing blocking later
checks and for old workouts being checked again. All four largest-text variants
of entry checks, sparse history and corrected metric labels passed. All 68 new
largest-type captures and 20 normal captures were inspected. Physical Apple
sign-in and replacement installation remain unverified.

The signed archive and IPA passed identity, HealthKit and Apple sign-in
entitlements, profile, privacy manifest, icon, version, staging endpoint and
debug-hook checks. Existing certificate reused.

- Archive: `apps/ios/build/release/2610062144/Exerly.xcarchive`
- IPA: `apps/ios/build/release/2610062144/export/Exerly.ipa`
- Logs: `apps/ios/build/release/2610062144/{archive,export,upload}.log`
- Bundle: `com.exerly.fitness`, Apple bundle resource `UJ5X8TJKNL`.
- Team: `9X79V37Q89`. Distribution certificate expires2027-09-25.
- Exerly profile: `J5J395Y9AF`, expires2027-09-25, HealthKit and Apple sign-in.
- App Store Connect: Exerly, app ID `6819776832`, created through the website.
- Internal group: `Exerly Internal · Ali`, `c5ae1d39-0fe4-4bee-af89-0374d9519afe`; only Ali, no public link or automatic future builds.

Bad build2610061633 used an incompatible production API and was detached.
Credentials and signing material stay outside the repository. Build outputs
are ignored. No other app's identifiers or profiles changed.

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
| Internal TestFlight upload        | Available internally  | 1.0 (2610062144), valid and in beta testing; only Ali and only this build.                                                                             |
| Feature parity                    | Open                  | Every PARITY.md row must have device evidence.                                                                                                         |
| Beyond                            | Open                  | Ship and measure B01-B12; no unproven superiority claims.                                                                                              |
| Native test suite                 | In progress           | Final A5: API 226, Core 233, 123 hosted tests and25 UI journeys pass; eight opt-in skips. Device build passes.                                         |
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
| Privacy policy                    | Open, Ali review      | Plain-language retention/deletion, HealthKit, provider disclosures and cloud opt-in; needs hosted URL.                                                 |
| HealthKit purpose strings         | Partial               | Capability/signing fixed; final type-by-type permission/consent audit remains.                                                                         |
| Cloud inference consent           | Open                  | Existing Gemini feature requires disclosure/opt-in redesign before public release.                                                                     |
| Encryption/export compliance      | Draft                 | App uses platform TLS/Keychain, no custom encryption; Info declares no non-exempt encryption. Ali reviews legal declarations before public submission. |
| Age rating                        | Open, Ali review      | Complete current questionnaire based on shipped features; no medications or medical claims.                                                            |
| Name/subtitle/description         | Draft below           | Verify lengths, actual functionality and name availability in ASC.                                                                                     |
| Keywords/category/copyright       | Draft below           | Fitness category, Sideband copyright and accurate search terms.                                                                                        |
| Screenshots                       | Open                  | Synthetic data only, final UI, all required device sizes and localizations.                                                                            |
| Support URL                       | Partial               | https://sideband.studio resolves and lists hello@sideband.studio; prepare Exerly-specific help/deletion guidance.                                      |
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

## Internal test notes for the account build

Enable Tailscale before signing in to Exerly staging. Use synthetic data.
Try email sign-in, a workout offline, relaunch, reconnect and Profile > Sync.
Profile > Account contains sign-in methods, export options and account deletion.
Exports include unsynced training; queued food and other legacy entries are
not included yet, as the screen explains. Native Apple sign-in/linking and
deletion reauthorization need physical-phone testing. Agent suggestion review
and connected-agent settings follow in A4. Report crashes through TestFlight.

[apps]: https://developer.apple.com/documentation/appstoreconnectapi/apps
[invite]: https://developer.apple.com/documentation/appstoreconnectapi/betatester/attributes-data.dictionary

## Test account and release smoke

Credentials are kept outside the repository in ~/private_keys/exerly-testflight-account.json.
The account contains synthetic onboarding only. Set TEST_RUNNER_EXERLY_ACCOUNT_SMOKE_PATH
to that file for AccountInfrastructureTests/testInternalTestAccountCompletesNativeSignInAndBootstrap.
This tests the app target’s compiled endpoint, Keychain session persistence, login and
bootstrap; it caught the difference from the stale production API. Hosted Core Keychain
replacement/isolation/accessibility/removal also passes. Neither test prints credentials.
