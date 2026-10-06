# Exerly release readiness

Updated 2026-10-06. Internal TestFlight is authorized. External TestFlight and App
Review require Ali's decision after the build and review material are ready.

## Current build

Version 1.0, build 2610061518. Signed archive and IPA exported successfully with
Xcode 26.2 and the iOS 26.2 SDK. Archive identity, HealthKit entitlement, profile,
privacy manifest, icon, version and absence of debug fixture hooks passed the
release validator. No upload or physical-device install has occurred.

- Archive: `apps/ios/build/release/2610061518/Exerly.xcarchive`
- IPA: `apps/ios/build/release/2610061518/export/Exerly.ipa`
- Logs: `apps/ios/build/release/2610061518/{archive,export}.log`
- Bundle: `com.exerly.fitness`, Apple bundle resource `UJ5X8TJKNL`.
- Team: `9X79V37Q89`. Reused distribution certificate, expires 2027-09-25.
- Exerly profile: `H5896RXW3D`, expires 2027-09-25. HealthKit enabled.
- App Store Connect app ID and internal group: pending website record creation.

Build and signing outputs are ignored. Keys, certificate material, passwords and
profiles stay outside the repository. No other app's identifiers or profiles changed.

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
`yymmddHHMM`. The script refuses to overwrite an archive. Signed modes use a
temporary keychain, restore the prior keychain list and remove only the profile
they installed. `--archive` produces a signed IPA without an upload. `--upload`
exports for internal testing only, checks that the app record exists, then uploads.
Run `internal BUILD_NUMBER` only after Apple reports the build as valid. It checks
that the existing tester is Ali and internal, and that the group has no public
link, no other members and no automatic access to future builds.

The [Apple API cannot create the initial app record][apps]. The app agent is
attempting the website through the existing desktop browser as Ali requested.
The aldo desktop session was locked at the time of the attempt. This blocks only
record creation/upload, not local work.

## App Store checklist

| Item                              | State                 | Acceptance and next action                                                                                                                             |
| --------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Bundle registration               | Done                  | Only com.exerly.fitness registered; HealthKit enabled.                                                                                                 |
| Distribution signing              | Done                  | Existing certificate reused; signed archive and export verified.                                                                                       |
| App icon                          | Built                 | Original 1024px opaque monogram; inspect installed home-screen appearance.                                                                             |
| App Store Connect record          | Blocked               | Website creation needs unlocked/signed-in desktop session.                                                                                             |
| Internal group                    | Pending record        | Create Exerly Internal with only Ali, no public link.                                                                                                  |
| Internal TestFlight upload        | Pending record        | Upload, poll processing, assign build, verify install.                                                                                                 |
| Feature parity                    | Open                  | Every PARITY.md row must have device evidence.                                                                                                         |
| Beyond                            | Open                  | Ship and measure B01-B12; no unproven superiority claims.                                                                                              |
| Native test suite                 | In progress           | 68 unit tests pass; full UI rerun after iOS 26 password-sheet fix.                                                                                     |
| Light/dark and Dynamic Type       | Open                  | Inspect all major flows at largest text on small/large phones.                                                                                         |
| VoiceOver/contrast/reduced motion | Open                  | Device audit, accessible form errors and charts, no clipped controls.                                                                                  |
| Performance                       | Open                  | Cold-launch measurements and 60 fps scrolling traces on a physical phone.                                                                              |
| Offline and conflict behavior     | Partial               | Existing queue tests pass; every new domain needs equivalent device journeys.                                                                          |
| Sign in with Apple                | Open                  | Logic contract plus native button, nonce and error flow.                                                                                               |
| Account deletion                  | Open                  | Reauthentication, confirmation, server deletion and local cleanup.                                                                                     |
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

## Internal test notes for the foundation build

Synthetic accounts only. This build contains the earlier diary, onboarding,
preferences and progress screens. It is an engineering baseline. The new training
logger, proposal review, complete nutrients and migration flows are not present.
Check sign-in, diary portion edits, offline relaunch and local data preservation.
Report crashes through TestFlight. Do not import personal health data yet.

[apps]: https://developer.apple.com/documentation/appstoreconnectapi/apps
