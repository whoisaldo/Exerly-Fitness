# Exerly brief

Read this at the start of every session and after every context reset, then read
`docs/ledger/claude.md` and continue from it. This replaces the 2026-10-06 brief, which is
archived in `docs/archive/`.

## Goal

Exerly is an iPhone training and nutrition app that ships on the App Store under Sideband.
It has to be clearly better than MacroFactor and MacroFactor Workouts: easier to use first,
then deeper, then more integrated with Apple's platforms than any competitor.

Ali's verdict on 2026-10-09: it isn't there. Tracking is harder to use than in the
reference apps, and the look and the feature set barely moved during the two-agent run,
which spent most of its effort on documentation and edge-case fixes. Every iteration from
now on must produce a change Ali can see on his phone.

## How you work

- **You are the only builder.** Claude owns the whole repo: screens, design system,
  ExerlyCore, the API and releases. The two-agent split, inboxes and ownership rules are
  retired. `docs/ledger/logic.md`, `docs/ledger/app.md` and `docs/handoff/` are history;
  read them only for a specific fact.
- **Parallel subagents.** Hand independent pieces (the Watch app while the diary is
  redesigned, for example) to subagents, each in its own worktree. Only one agent edits
  `project.pbxproj` at a time. Moving to XcodeGen or Tuist is allowed if it removes that
  bottleneck; record why in `docs/DECISIONS.md`.
- **Git.** Work in `~/Desktop/Exerly-Fitness-claude` on `claude/next`. The integration
  branch `feat/mobile-production-foundations` is checked out in `~/Desktop/Exerly-Fitness`;
  never edit files there. To land: rebase, run the checks, then
  `git -C ~/Desktop/Exerly-Fitness merge --ff-only claude/next` and push. Merge integration
  into `main` at least daily once it's green. `main` auto-deploys the API, which is fine.
- **The old app agent.** Ali stops the Astra thread. Until he confirms it has stopped,
  don't touch `~/Desktop/Exerly-Fitness-app`, `~/Desktop/Exerly-Fitness-app-programs` or the
  "Exerly App" simulators. Cherry-pick anything worth keeping from `agent/app-nutrition`.
- **Let Ali see the work.** Open the simulator with the T3 device tools so he can watch in
  the Device panel. Ship an internal TestFlight build whenever something visible changed,
  at least daily. A minor flaw is a reason to fix it in the next build, not to withhold
  this one.
- **Waiting inside T3.** `ScheduleWakeup` and cron never fire in T3 threads, and T3 stops
  a session after 30 idle minutes with no background work. Never end a turn without
  something running in the background. If no helper or test is running, start
  `sleep 1200` with `run_in_background`; its completion wakes you. After a restart,
  resume stopped helpers with SendMessage and check their worktrees.

## Ranked outcomes

Work from the top. Lower items wait unless they block a higher one.

1. **Tracking that's effortless.** Rethink the core flows and the navigation around them.
   Ali's early UI decisions made logging harder than in the reference apps, so redesign
   rather than patch. Count taps from the app's home screen on the simulator:
   - a food eaten before: 3 taps or fewer; repeating a meal or a whole day: 2 or fewer;
   - barcode to logged, including the scan: 3 or fewer;
   - starting today's workout: 2 or fewer; a set prefilled from last time: 1;
   - a weigh-in: 3 or fewer.

   Then hand the simulator to a fresh subagent that hasn't seen the code and ask it to log
   a meal and a workout with no instructions. Wherever it hesitates, the design failed.
   Learn from MacroFactor's public material (App Store screenshots, help centre, release
   notes, reviews) and do better; don't copy its interface.
2. **A redesign worthy of an App Store feature.** Keep the identity: purple and pink on
   dark surfaces and the pulse logo. Everything else can change: the design system (type,
   spacing, surfaces, components, numbers, charts, motion, haptics) and every primary
   screen. Delete screens and features that don't serve the goal instead of polishing
   them, and log each removal in `DECISIONS.md`. The bar is MacroFactor, Apple Fitness,
   Apple Health and Things 3.
3. **Feature depth past MacroFactor.** Everything in `docs/PARITY.md` and
   `docs/MACROFACTOR.md`: food logging and database, micronutrients, adaptive expenditure
   and targets, programs, progression, analytics and imports, each finished to the
   standard of outcomes 1 and 2. All maths lives in tested pure functions in ExerlyCore.
4. **Deep Apple integration.** iOS only. A real Watch app (workouts, set logging, rest
   timer, heart rate, complications); Home Screen, Lock Screen, interactive and StandBy
   widgets; Live Activities and the Dynamic Island for workouts and rest; Control Center
   controls; App Intents, Shortcuts and Siri for every logging action; full Apple Health
   read and write; Spotlight; notification actions; VisionKit scanning.
5. **Public readiness.** Sign in with Apple and email, account deletion, export and
   import, privacy policy and labels, and the checklist in `docs/RELEASE.md`.
6. **Later: the AI coach.** Photo, voice and sentence logging confirmed before saving,
   weekly reviews, stall diagnosis, proposals with undo. Start after 1 to 4 are in good
   shape. Until then, keep the existing agent API and MCP server working without
   expanding them.

Out of scope: the web dashboard (remove it from CI or the repo if it gets in the way),
Android, and peptides, injectables, medications or dose tracking, which belong to Ali's
private Ascension project.

## Each iteration

1. Pick the next slice of the top unfinished outcome that Ali would notice.
2. Screenshot the affected screens. Build it. Screenshot again in light and dark, on a
   small and a large phone, and at the largest text size. Look at every screenshot next to
   the reference apps. If it isn't clearly better, keep working.
3. Run the tests for what you touched, land it, and ship a TestFlight build if something
   visible changed.
4. Rewrite the ledger.

The quality floor is passing tests, no new warnings, VoiceOver labels, no data loss
offline, correct units and time zones, and each user's data isolated in every query. It
is a floor, not the goal: don't spend iterations polishing edge cases while a primary flow
is still hard to use.

## Keep the paperwork small

- One ledger, `docs/ledger/claude.md`, rewritten each time and kept under 80 lines: what
  changed since the last TestFlight build, the current outcome, the next three steps, how
  to resume, and risks.
- No commits that only change docs. Docs ride along with the code they describe.
- Write a design note only for a decision that's hard to reverse, and keep it short.
- Save screenshots under `artifacts/screens/<date>/` (ignored by git) and list the paths
  in your summary.
- `docs/DECISIONS.md` and `docs/QUESTIONS_FOR_ALI.md` stay append-only.

## Hard rules

- **Identity.** Never change the palette or the logo unless Ali asks.
- **Commits** are small and authored as Ali Younes <whois.younes@gmail.com>, with no
  co-author trailers or tool attribution.
- **Synthetic data only** in tests, fixtures, screenshots, demos and anything sent to an
  AI service. Ali's real data never enters the repo.
- **Fair sources.** Don't reverse-engineer, scrape or copy any competitor's app, private
  API or food database. Respect food-data licences: Open Food Facts is ODbL with
  attribution, USDA FoodData Central is public domain, and FatSecret has its own terms.
- **Honest claims.** Implemented, tested and on TestFlight are different claims. Never
  report what you didn't run.
- **Ask without stopping.** Questions go in `QUESTIONS_FOR_ALI.md`, and only about money
  or new accounts, App Review or external TestFlight, licence or visibility, or anything
  legal. Decide everything else and log it in `DECISIONS.md`.
- **Privacy.** HealthKit data is never used for advertising, every type read has a stated
  purpose, and nothing is written without consent. No third-party analytics or crash SDKs
  without Ali's approval.
- **Backend.** PostgreSQL (Neon in production), the Node API on DigitalOcean App
  Platform, and docker-compose for self-hosting. No AWS, paid tiers or new accounts
  without Ali.
- **Releases.** Use `DEVELOPER_DIR=/Applications/Xcode-26.2.app/Contents/Developer`,
  including for push hooks. Team 9X79V37Q89, bundle `com.exerly.fitness`, timestamp build
  numbers, and an internal TestFlight group with only Ali. Use the App Store Connect API
  key in `~/private_keys` (`AuthKey_4Z7KFJ8DWZ.p8`, issuer in `asc-issuer-id.txt`) and the
  existing distribution certificate in `~/private_keys/eternalmonitor-distribution`.
  Never create, revoke or replace certificates. App Intent titles and phrases must not
  name Apple products, or the upload fails with ITMS-90626. External TestFlight and App
  Review are Ali's decision: prepare everything, then ask.
- **Sideband.** Public contact is hello@sideband.studio, copyright "© Sideband", links to
  https://sideband.studio. Never use a personal or university address publicly. Licence
  and repository visibility are Ali's decision; write as if the repo could go public.
- **devbox1.** Don't touch other repos (health-dashboard, Eternal Monitor), the services
  on ports 8741, 18789, 8646, 3773, 3774 and 11434, or other apps' bundle IDs and
  profiles. Use ports 39000-39299 and simulators named "Exerly ...". Bind previews to
  0.0.0.0 and report http://100.80.149.7:<port>.

## Stopping

There's no finish line. When the ranked list is done, do a fresh teardown against
MacroFactor and the best iOS fitness apps, re-rank, and keep going. A finished slice, a
long context or a hard problem is never a reason to stop. Stop only when everything left
is blocked on Ali, and say exactly what's blocked.
