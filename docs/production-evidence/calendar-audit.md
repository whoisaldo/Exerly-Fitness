# Account calendar audit

September 22, 2026. The defect below now has [browser](calendar-browser.md) and [native logging fixes with passing regression checks](calendar-native.md). Wider native boundary and health-import coverage remains open.

An isolated browser reproduction used a saved `America/New_York` account and a browser configured as `Pacific/Kiritimati`. At `2026-09-22T17:51:42Z`, the API's default summary returned September 22. The browser called September 23 "Today" and enabled water additions. Adding 250 ml sent that future date and the API rejected it with HTTP 400, "Cannot log to a future date".

[Reproduction values](calendar-audit/reproduction.json) and [browser capture](calendar-audit/today-zone-mismatch.png) preserve the evidence. The reproduction used its own fixture on port 39005 and web server on port 3305. Both processes were stopped afterwards. No production account was used.

## Causes found in the reproduction

- Browser `src/lib/dates.ts` derives today from the browser zone. Diary, activity/sleep, weight, measurements and date-navigation controls use this helper even after bootstrap supplies the account time zone. The older Dashboard also uses an ISO UTC date for one operation.
- Native `APIClient.dayString` and `date(fromDayString:)` use `TimeZone.current`. Native date pickers, date arrows, measurement ranges and day-bound validation also use the device calendar. `AuthViewModel` currently installs the saved display units but no account calendar context.
- The API intentionally gives the saved account time zone priority over the request header. New logs without an explicit date use that account day, and explicit future dates are rejected.
- Local reminders already use the saved account time zone. Their calendar behavior is independent of this daily-log defect.

## Next implementation invariants

1. Compute Today, date labels, input bounds and default query ranges from one account calendar in both clients. Anonymous setup can initially suggest the device zone. Signing out or changing accounts must not carry another account's calendar into the new session.
2. Preserve an explicitly chosen calendar day through sheets, scanning, backgrounding, edits and preference changes. A date-only value must not become another date when a time zone changes.
3. Keep persisted mutation bodies and operation identities unchanged. Existing dates must not be silently rewritten by a display-preference update. Define recovery for an unsent entry whose original day is temporarily ahead of the account after travel or a time-zone change.
4. Use Gregorian calendar-day arithmetic and strict validation. Test month/year boundaries, leap days, DST transitions, and zones on opposite sides of the date line. Do not assume every local day is 24 hours or that every local midnight exists.
5. Keep timestamps distinct from calendar days. Older device-only measurements store timestamps without the original zone; their explicit import review must show the chosen date before adoption.
6. Verify native/browser/API/export agreement, including account changes and offline relaunch. Add the reproduced water failure as a browser regression, plus corresponding native day-selection tests.
