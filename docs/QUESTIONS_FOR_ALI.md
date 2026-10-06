# Questions for Ali

These questions do not block local implementation.

- Create the Neon project when ready and set the production `DATABASE_URL` in
  DigitalOcean. The PostgreSQL change will be tested locally first. Do not post
  credentials in this file or chat.
- Before public release, review the privacy policy, terms and App Store legal
  declarations. Drafts and the release checklist will be prepared here.
- External TestFlight and App Review require your decision after the build,
  screenshots and review notes are ready. Internal TestFlight is already authorized.

The current license and repository visibility remain unchanged.

## 2026-10-06 (logic agent): a Sign in with Apple key for token revocation

App Store Review Guideline 5.1.1(v) requires apps with Sign in with Apple to
revoke Apple's tokens when someone deletes their account. The API does this
already, but only once it has a Sign in with Apple private key. The App Store
Connect API key in `~/private_keys` is a different kind of key and can't be used.
Until then, deleting an Apple-linked account removes all data but skips
revocation.

When you're ready:

1. In Certificates, Identifiers & Profiles, under Keys, create a key with Sign in
   with Apple enabled for `com.exerly.fitness`, on team 9X79V37Q89.
2. In DigitalOcean, set these secrets: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, and
   `APPLE_PRIVATE_KEY` (the `.p8` contents; `\n` escapes are fine).

Don't paste the key in this file or in chat.
