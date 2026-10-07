# Privacy publication review

Prepared 2026-10-07 from the app and API source at 4172379b. This is an audit
draft, not a submitted App Store declaration or legal approval.

Apple's [privacy details guidance](https://developer.apple.com/app-store/app-privacy-details/)
distinguishes data retained off device from processing confined to the device.
The declaration must cover the app and its service providers. The account
deletion flow must remain available in the app, as described in Apple's
[account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion).

## Data map for the current native build

| Data                                            | Current path                                             | Candidate declaration                                                                            |
| ----------------------------------------------- | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Name and email                                  | Profile, authentication, account server                  | Linked to account; app functionality                                                             |
| Account and sign-in identifiers                 | Server identity and session records                      | Linked user ID; app functionality                                                                |
| Food, weight, measurements, sleep and targets   | Account records and sync                                 | Linked health data; app functionality                                                            |
| Workouts, sets, programs and activity           | Account records and sync                                 | Linked fitness data; app functionality                                                           |
| Notes, saved labels, proposals and decisions    | Account records and audit history                        | Linked other user content; app functionality                                                     |
| Profile age, sex and timezone                   | Account profile, target calculations                     | Confirm the additional category and personalization purpose before submitting                    |
| Search terms and barcodes                       | Server to Open Food Facts; temporary shared search cache | Review search-history disclosure and provider retention, including searches not saved to a diary |
| Steps and active energy read in Health settings | HealthKit to local presentation only                     | This screen does not transmit these readings; manually logged health records above are separate  |
| Progress photos                                 | System photo picker to local SwiftData records           | No Exerly account upload; device backup settings may apply                                       |
| IP addresses and request diagnostics            | Network hosts and rate limiting                          | Hosting/log retention must be reviewed before choosing the final diagnostic categories           |
| TestFlight feedback and crash reports           | Apple beta service                                       | Confirm what Sideband accesses and retains; no additional crash SDK is present                   |
| Agent-selected data                             | Scoped token/API, to the chosen agent                    | User-directed sharing; document scopes and revocation, plus provider responsibilities            |

The existing privacy manifest lists name, email, user ID, health, fitness and
other user content as linked and used for app functionality, with no tracking.
It declares the app's UserDefaults reason. The table above is a wider review;
do not assume that the manifest alone completes the App Store questionnaire.

## Source checks

- HealthReadModel requests steps and active energy, with an empty write set.
  Its Core readers return values to this screen, with no account mutation.
- PhotosTab uses the system photo picker and local ProgressPhoto storage.
- The native food endpoint calls Open Food Facts. Provider attribution remains
  visible; there is currently no USDA native search request without a contract.
- Account deletion removes owned rows and identities. Apple token revocation
  needs the separate configured Sign in with Apple key described in
  QUESTIONS_FOR_ALI.md. A passing simulated authorization test does not prove
  that production revocation is configured.
- Legacy AI service code still exists, but its old coach screen is unreachable
  from the current shell. Do not publish a blanket claim that every Exerly API
  route avoids cloud inference. Any future app route needs disclosure and opt-in.
- No advertising, analytics or crash SDK is added by this release.

## Decisions required before publishing

Ali reviews the notice and legal declarations. Logic confirms the deployed data
flows and operational settings. Resolve these concrete items:

1. Production operator details, supported age range and privacy contact wording.
2. Production hosting providers, locations, database encryption, log retention,
   backup retention and deletion from backups. Do not invent retention periods.
3. Applicable rights, request verification and any legally required retention.
4. Sign in with Apple revocation key and physical authorization/deletion proof.
5. Final App Store categories for profile fields, cached searches and diagnostics,
   and whether recommendations require the product-personalization purpose.
6. Public HTTPS policy and support URLs under Sideband. The drafts are local;
   no website or App Store declaration has been changed.

The internal staging build is restricted to the private tailnet and synthetic
data. It does not establish production TLS, database or backup readiness.
