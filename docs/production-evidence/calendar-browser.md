# Browser account calendar

September 22, 2026. These checks use isolated API fixtures and synthetic accounts.

The browser now derives Today from the signed-in account's saved time zone. One account-scoped calendar supplies diary, activity, sleep, weight, measurement, program labels and date-input bounds. The dashboard's fallback history filter and date heading use the same account calendar. Administrator log rows display the stored calendar date directly instead of converting it through the administrator's local zone.

Date-only values stay Gregorian `YYYY-MM-DD` strings. Validation rejects impossible dates, and calendar arithmetic uses UTC components without interpreting a day as an elapsed local-time interval. Signed-out and replacement accounts do not retain the prior account's calendar context.

Diary, activity, sleep and weight pages retain the selected day in their URL. Reload restores that day even if midnight has passed or the account time zone has changed. Opening a navigation link without a date chooses the account's current day. The Today button also moves to the current account day. Food sheets capture their date when opened. Browser focus, visibility changes and a periodic clock refresh update labels and bounds without changing a draft's date.

Changing the account time zone can put a saved draft ahead of the new Today. The browser retains the explicit date and pending request body, explains why it is ahead, and offers the original retry. The server can reject a still-future date; the pending operation remains available until that date arrives or the account time zone is corrected. The retry identity and payload are never rewritten to another day.

## Verification

- All three initial browser reproductions failed on the old implementation. Account and browser zones on opposite sides of the date line disagreed about Today, and a timezone change replaced the selected pending day. [Reproduction log](calendar-browser/reproduction-tests.log).
- Five focused checks pass in `/tmp/exerly-calendar-web-v4.log`: four browser journeys and one calendar arithmetic check. The journeys cover both directions across the date line, successful water additions and export agreement, activity/sleep/measurement defaults and bounds, switching accounts, unchanged pending water retries, and a food flow crossing midnight. [Focused log](calendar-browser/focused-tests.log).
- Calendar arithmetic checks include leap days, year boundaries, spring and autumn DST transitions, a skipped local date in Pacific/Apia, invalid dates and invalid-zone fallback.
- A stronger [reload reproduction](calendar-browser/reload-reproduction.log) found that a default Today route could lose its selected day after a time-zone change. The shared date-selection hook now puts the opened day into the URL. The final suite starts the pending-water journey from the default route and checks recovery across reload.
- The midnight test initially installed its simulated clock after the application had created its timers. Installing it before navigation made the timer check valid. The passing test observes the new day's input bound while the open food flow saves to its original day.
- TypeScript and the production browser build pass in `/tmp/exerly-calendar-build-v3.log`. Changed-file ESLint passes with ten existing warnings in Dashboard and Admin. The bundle-size warning remains.

The final browser regression passes 42 tests with one native-dependent test skipped in `/tmp/exerly-calendar-browser-all-v2.log`. This includes all five calendar checks after the URL restoration fix. [Full browser log](calendar-browser/browser-regression.log). The shared native-dependent journey passed in the preceding session batch's cross-client v11 run; the new native calendar behavior still needs its own implementation and round trip.

## Captures

- [Account west of the browser, successful water entry](calendar-browser/account-west-of-browser.png)
- [Account east of the browser, successful water entry](calendar-browser/account-east-of-browser.png)

Both captures were reviewed at a 390-pixel browser width.

## Remaining work

Native day formatting, pickers, date ranges and legacy measurement import still use device-calendar behavior. That implementation and its simulator/browser round trip remain open. Browser offline startup and observing account preferences changed on another device are also separate foundation work. This batch does not close the account-calendar acceptance criteria for both clients or any public-release gate.
