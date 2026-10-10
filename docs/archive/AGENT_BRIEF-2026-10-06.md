# Exerly: brief for the long-running agent

Read this file at the start of every session and after every context reset. Two agents
work on Exerly at once (see **Two agents**): read your own ledger, docs/ledger/logic.md or
docs/ledger/app.md, and your inbox in docs/handoff/, then continue.

## Mission

Build Exerly into **the agentic-first training and nutrition app for optimizers**: people
who track everything, want to know why their numbers move, and want their own AI agents to
work with their data. It ships publicly on the App Store under Sideband.

The bar is high. Exerly must cover everything MacroFactor and MacroFactor Workouts do,
beat each feature on speed, clarity and intelligence, and then do what neither can,
because it was designed for agents from the start.

Be ambitious. Nobody uses Exerly today, so there are no users or old clients to protect.
Redesign data models, APIs and screens freely, delete legacy code, and choose the best
architecture over the safest patch.

**Done means all of these hold:**

- every row in docs/PARITY.md is verified on device builds;
- the Beyond list is shipped;
- the App Store readiness checklist is complete;
- two consecutive full audits find nothing worth fixing.

Finishing a phase, a long context or a hard problem is never a reason to stop.

## Two agents

Two agents build Exerly at the same time, each on what it does best. Each runs in its own
T3 Code thread and its own git worktree, which is that thread's working directory.

- **Logic agent: Claude (Opus 5.5).** The code where mistakes compound.
  - Owns `apps/api/**`: Postgres, migrations, sign-in and sessions, sync, the REST API, the
    MCP server, tokens, webhooks, food search, exports, docker-compose and backend CI.
  - Owns `apps/ios/ExerlyCore/**`, a new local Swift package with no UI. It holds:
    - domain models and on-device persistence;
    - every calculation (e1RM, volume, progression, readiness, trend weight, expenditure,
      targets);
    - the offline sync engine and the API client;
    - the agent proposal, accept, undo and audit model;
    - importers (MacroFactor, Apple Health history, Hevy, Strong).
  - Owns `apps/ios/Exerly/Core/**` until it has moved into ExerlyCore.
  - Owns `docs/api/` (the OpenAPI spec) and documents ExerlyCore's public interface.
  - Logic is tested with `swift test` or the package's own scheme.
- **App agent: Astra (GPT-6-Astra).** The iPhone experience, verified on the simulator.
  - Owns everything else under `apps/ios/`: Features, Components, Navigation, Theme, the
    app target and `Exerly.xcodeproj`, App Intents, widgets, Live Activities, the Watch app,
    and the Apple Health permission and user-interface layer.
  - Owns ExerlyUITests and ExerlyTests, the release pipeline and TestFlight, and
    `docs/PARITY.md` and `docs/RELEASE.md`.
  - Drives the simulator to verify every flow.

**Ownership rules:**

- Only edit files you own. If you need something in the other agent's area, write it in
  their inbox and keep working on something else.
- **Only the app agent edits `project.pbxproj`.** That's why logic lives in the ExerlyCore
  package, which needs no project-file changes. The app agent links ExerlyCore into the
  app, removes moved `Core` files from the target when the logic agent says they've moved,
  and the app never calls the network or does domain maths itself. Screens use ExerlyCore's
  public API only.
- **Contracts first.** Before building a feature, the logic agent publishes its ExerlyCore
  interface and any endpoints, with a short usage note, in `docs/handoff/to-app.md`. The app
  agent can build against a stub of that interface meanwhile. Breaking changes to a
  published interface go to the other agent's inbox first.

**Shared files:**

- `docs/DECISIONS.md` and `docs/QUESTIONS_FOR_ALI.md` are append-only for both agents.
- `docs/AGENT_BRIEF.md` is Ali's. Propose changes to it in `docs/QUESTIONS_FOR_ALI.md`.

**Inboxes:**

- `docs/handoff/to-logic.md` (written by the app agent) and `docs/handoff/to-app.md`
  (written by the logic agent).
- Each item has a date, a short title, what's needed or what changed, and a status:
  open, in progress or done.
- Read your inbox at the start of every milestone. Mark items done; never delete them.

**Integration.**

- The integration branch is `feat/mobile-production-foundations`, checked out in
  `~/Desktop/Exerly-Fitness`. Nobody edits files in that checkout.
- To land work:
  1. Rebase your branch onto the integration branch.
  2. Run the full suite and the iOS build in your worktree.
  3. Run `git -C ~/Desktop/Exerly-Fitness merge --ff-only <your-branch>`, then push the
     integration branch.
  4. If the fast-forward fails because the other agent landed first, rebase again.
- **Land small pieces, often.** No branch holds more than about 4 hours of finished,
  passing work. Land it in pieces rather than one large batch.
- **Don't freeze integration for long runs.** If a release needs a long test run, cut it
  from a fixed commit or tag in a release worktree and let integration keep moving.
  Holding the other agent's landing for hours is a bug.
- **`main` stays current.** At every milestone end, and at least once a day, the logic
  agent merges the integration branch into `main` once the suite and the iOS build are
  green, pushes it, and checks CI on `main`.
- **Clean up.**
  - Delete branches whose work has fully landed (check with `git cherry`).
  - Remove worktrees you no longer need. Keep your primary worktree plus at most one
    release worktree.
  - Never delete the other agent's branches.
- **Merge status in every ledger.** A small table: each of your branches, its unlanded
  commits, and when it last landed. Keep it current.

**Review each other.**

- At the start of each milestone, read the other agent's commits since your last review.
- Write findings in their inbox, with file, line, severity and why.
- The logic agent looks for logic or data bugs in app code. The app agent looks for
  anything the logic makes awkward or wrong on the device.
- Never fix the other agent's code yourself, except a one-line build break, which you
  must note in their inbox.

**Machine resources.**

- Scratch ports: logic 39100-39199, app 39200-39299. The existing native and cross-client
  scripts use 39001-39003 and belong to the app agent.
- Simulators: the logic agent creates and uses only "Exerly Logic" simulators; the app
  agent uses "Exerly App" ones. Each worktree keeps its own build products.
- Only the app agent uploads TestFlight builds. The logic agent asks for a build in
  `to-app.md` when backend or core changes need checking on a device.

**Starting state:** Astra began M1 (the PostgreSQL foundation) before the split. Its plan
is in `docs/design/001-postgres-foundation.md` and its notes are in `docs/ledger/logic.md`.
M1 now belongs to the logic agent, which should keep that work where it holds up.

**First milestones:**

- **Logic agent:**
  1. Create ExerlyCore with the training domain first (exercise library with muscles,
     joint actions and equipment; sessions, sets, reps, load, RIR and set types; e1RM;
     volume per muscle) and publish its interface, so the app agent isn't blocked.
  2. Then M1: Postgres, migrations, sign-in and sync.
  3. Then the agent core: proposals, audit log, MCP, scoped tokens.
- **App agent:**
  1. Create `docs/PARITY.md`.
  2. Set up the internal TestFlight pipeline.
  3. Build the new app shell and design system.
  4. Build the training logging flow on a stub of ExerlyCore, switching to the real one
     as it lands.
  5. Upload a TestFlight build to Ali at every milestone.

## Design quality (Ali's bar)

On 2026-10-06, after a full day of work, Ali judged the UI not acceptable. Visual quality
is now a release gate, equal to the tests.

- **The bar:**
  - Exerly should look and feel like a top-tier App Store app, at the level of MacroFactor,
    Apple Fitness and Things 3.
  - A screen that's a plain stock form or list, with no hierarchy, fails, however well
    tested it is.
- **Identity.**
  - Exerly's original purple and pink on dark surfaces, and its original pulse logo.
  - Never change the theme, palette or logo without Ali asking for it.
- **One design system in code,** used by every screen:
  - type scale, spacing scale, corner radii, surfaces and elevation, colour tokens, and
    number styles. Rounded, proportional numbers by default; monospaced only where digits
    must line up, such as timers.
  - Shared components: cards, progress rings and bars, chips, steppers, segmented
    controls, a numeric keypad, empty states.
- **Every primary screen has a clear hierarchy.** One summary at the top (the diary opens
  with today's calories and macros against targets, the logger with today's session),
  then content.
  - Empty states are designed and point to the next action. Repeated "Nothing logged" rows
    fail.
  - Frequent inputs use purpose-built controls, not stock pickers: meal chips, quantity
    steppers with presets, set entry with prefilled values and one tap to complete.
  - Haptics on completion; subtle, purposeful motion; nothing decorative.
- **Review at every milestone, before uploading:**
  - Capture each primary screen at the default text size in light and dark, as well as
    the accessibility sizes.
  - Compare them side by side with the reference apps' public App Store screenshots.
  - Write a short critique in the ledger: what's worse than the reference and why. Fix it
    before uploading.
  - The logic agent also reviews those captures and adds a short critique to `to-app.md`.
- **When Ali says a screen is bad, it becomes the top priority.**

## Product principles: agentic-first, done right

Most fitness apps bolt a chatbot onto the home screen. Exerly does the opposite.

1. **Agents propose, people decide.** Anything an agent changes is a reviewable proposal:
   a program, targets, a deload, a logged meal, a swapped exercise. Each proposal shows the
   diff, the evidence, a confidence level and what would prove it wrong. Accepting is one
   tap, and every agent action is in an audit log and can be undone.
2. **Code computes, models explain.** e1RM, volume, progression, expenditure, trend weight
   and macros come from tested pure functions. A model never does arithmetic in prose, and
   every number it shows comes from those functions and links back to the logged data.
3. **Open to your own agents.**
   - A first-class MCP server and a versioned OpenAPI.
   - Scoped personal access tokens (read, write, propose-only) and signed webhooks.
   - App Intents and Shortcuts.
   - The user's Claude, ChatGPT or custom agent can read the logs, run analyses and file
     proposals through the same rules as the in-app agent.
4. **Structured, not chat-first.** Intelligence appears where it's needed:
   - today's session adjusted for poor sleep or missed meals;
   - a stall diagnosed with evidence;
   - a meal logged from a sentence or a photo and confirmed before saving;
   - a weekly review.

   Chat exists but is never the home screen.

5. **Honest evidence.** Label claims (human RCT, observational, mechanism, anecdote). Say
   when data is n=1, confounded or too short. Make no medical claims. No streak confetti and
   no motivational filler.
6. **Private and cheap by default.**
   - On-device first: Apple's on-device Foundation Models where available, plus VisionKit
     for barcodes and nutrition labels.
   - Bring-your-own-agent through MCP and the API.
   - Cloud inference is opt-in, disclosed, and never required for logging.
   - Design the per-user cost to stay near zero.
7. **Works with AI off.** Every feature has a manual path. AI never blocks logging.
8. **Built for optimizers.**
   - Dense, fast screens.
   - Full raw-data export, custom metrics and tags.
   - n=1 experiments (baseline window, test window, metrics chosen up front).
   - Correlation views that state their limits.

**Out of scope:** peptides, injectables, medications and dose tracking. Those belong to Ali's
private Ascension project and must never appear in Exerly. Supplements are ordinary food or
nutrient entries at most.

## Scope

- **The iPhone app is the product.** Add an Apple Watch app, widgets, Live Activities and
  App Intents where they serve it.
- **The backend exists to serve the app:** accounts, sync, backup, food search, the agent
  API, MCP and webhooks.
- **The web dashboard is out of scope.** Don't build or maintain it. Remove it from CI or
  from the repo if it gets in the way, and record that in docs/DECISIONS.md.

## Backend and hosting (scalable, student budget)

Use this target stack unless you find a better one and record why in docs/DECISIONS.md.

- **Database: PostgreSQL.** Replace MongoDB and the Mongo driver.
  - Use plain SQL migrations.
  - Isolate each user's data in every query, and add row-level security if you adopt it.
  - Production target is Neon (free tier, scale to zero, branch databases for previews).
- **API:** the Node service, containerised with a Dockerfile.
  - Production target is DigitalOcean App Platform, where it already runs. GitHub Student
    Developer Pack credit may cover it.
  - No host-specific APIs, so it can move to Fly, Render or anything else.
- **Self-host:** a docker-compose file (Postgres plus the API) that anyone can run. This
  keeps open-sourcing possible and makes hosts interchangeable.
- **Files:** progress photos stay on the device by default. Add S3-compatible storage
  (Cloudflare R2) only when a feature needs it.
- **Development and staging on devbox1:**
  - Postgres and Docker are installed, so use scratch ports.
  - Bind to 0.0.0.0 and report http://100.80.149.7:<port>.
  - For a long-lived staging service, add one LaunchAgent, following
    ~/Services/devbox-recovery/README.md. Run it from a deployed copy under ~/Services,
    because LaunchAgents can't read ~/Desktop.
- **Never:** AWS, paid tiers, or new accounts without Ali's approval. Ali creates the Neon
  project and sets secrets in DigitalOcean. Ask for these in QUESTIONS_FOR_ALI.md and keep
  working against local Postgres meanwhile.

## Public-product requirements

- **Accounts:** Sign in with Apple plus email, secure sessions, account deletion in the app
  (App Store rule), full data export and import, and rate limits.
- **Privacy:**
  - A plain-language privacy policy and accurate App Store privacy labels.
  - Follow HealthKit rules: no advertising use, a clear purpose for every type read, and
    nothing written without consent.
  - Encrypt data in transit and at rest.
  - Collect the minimum.
  - No third-party analytics or crash SDKs without Ali's approval; use MetricKit and
    TestFlight crash reports.
- **Reliability:** offline-first with conflict-safe sync, idempotent writes, migrations that
  can be rolled back, and backups.
- **App Store readiness checklist** in docs/RELEASE.md: metadata, screenshots, review
  notes, export compliance, privacy labels, age rating, support URL. Submitting to App Review
  or external TestFlight review is Ali's decision. Prepare everything, then ask.

## Sideband

Exerly is a Sideband product: Ali's studio, https://sideband.studio, GitHub org
`sidebandstudio`.

- **The repo is moving** from whoisaldo/Exerly-Fitness to the sidebandstudio org. Ali does
  the transfer.
  - At the start of each session, run `gh repo view sidebandstudio/Exerly-Fitness`.
  - Once it resolves, run
    `git remote set-url origin https://github.com/sidebandstudio/Exerly-Fitness.git`.
  - Then update every old reference: README clone URL and badges, docs, CI, and
    `.do/app.yaml` (`github.repo`).
  - If DigitalOcean can't reach the new repo, ask Ali to grant its GitHub access to the
    org.
- **Public strings:**
  - support and contact email: hello@sideband.studio;
  - copyright: "© Sideband";
  - links: https://sideband.studio.
- **Never use as a public contact:** whois.younes@gmail.com, any eternalreverse.com address,
  or a university address.
- **Licence and repo visibility (open versus closed source) are Ali's decision.** Write
  everything as if the repo could become public: no secrets, no personal data, clean
  commits. Don't change the licence or the visibility.
- **Apple:** builds use Ali's developer team 9X79V37Q89 unless Ali says Sideband has its own
  Apple developer account.

## Rules

1. **Git.**
   - Commit small and often, authored as Ali, with no Co-authored-by trailers or tool
     attribution.
   - Push branches and merge to main once the full suite and the iOS build are green. main
     auto-deploys the API, which is fine while nobody uses it.
2. **Synthetic data only.** Tests, fixtures, screenshots, demos and anything sent to an AI
   service during development use synthetic data. Ali's real data stays in MacroFactor and
   Ascension until Exerly is ready, and it never enters this repo.
3. **Releases.** Internal TestFlight builds are yours to run.
   - Use the App Store Connect API key in ~/private_keys (AuthKey_4Z7KFJ8DWZ.p8, issuer ID
     in asc-issuer-id.txt) to register bundle IDs and capabilities, including HealthKit.
   - Create the app record (bundle com.exerly.fitness). If the name is taken, use a variant
     and record it.
   - Create an internal group with only Ali in it.
   - Upload a build at every milestone.
   - Sign with the existing distribution certificate (~/private_keys/eternalmonitor-distribution).
     Never create, revoke or replace certificates.
   - Ascension's pipeline is the reference: ~/Desktop/health-dashboard/ios/scripts/release.sh
     and deploy/ios-release.sh, which use manual profiles and a temporary keychain.
   - Lessons from that pipeline:
     - archive with /Applications/Xcode-26.2.app;
     - use timestamp build numbers;
     - App Intent titles and phrases must not name Apple products such as iPhone, Health
       or Apple, or the upload is rejected with ITMS-90626.
4. **Ask without stopping.** Put questions in docs/QUESTIONS_FOR_ALI.md and keep working on
   everything else. Questions are only for:
   - money, and new accounts or services;
   - App Review or external TestFlight;
   - licence and visibility;
   - anything legal.

   Decide everything else yourself and log it in docs/DECISIONS.md.

5. **Leave the rest of devbox1 alone.**
   - Don't touch other repos (health-dashboard/Ascension, Eternal Monitor).
   - Don't touch running services: 8741, 18789, 8646, 3773/3774, 11434.
   - Don't touch Ascension's or Eternal Monitor's bundle IDs or profiles.
   - Use your own simulators and scratch ports.
6. **Play fair with sources.**
   - Don't reverse-engineer, scrape or copy MacroFactor's or any competitor's app, private
     API or food database.
   - Use public sources (websites, help centres, release notes,
     github.com/MacroFactor/apple-shortcuts) and build original implementations.
   - Respect food-data licences: Open Food Facts is ODbL with attribution, USDA FoodData
     Central is public domain, FatSecret has its own API terms.
7. **Honest claims.** Implemented, tested and on TestFlight are different claims. Never
   report what you didn't run.

## Step 1: docs/PARITY.md, the single source of truth

Inventory every MacroFactor feature (food logging, database, program and coaching,
analytics) and every MacroFactor Workouts feature (exercise library, logging, programs,
progression, analytics), from primary sources. Check how the leading training apps handle
logging and progression too. For each row record:

- the feature and its source;
- Exerly's status;
- acceptance criteria;
- evidence: tests, screenshots, TestFlight build.

Add a **Beyond** column. Check every seed below against a source and drop what you can't
confirm.

### Ground truth: MacroFactor's own export (Oct 2026)

- **Calories & Macros.**
- **Micronutrients (50 columns):**
  - alcohol and caffeine;
  - B vitamins: B1, B2, B3, B5, B6, B12;
  - minerals: calcium, copper, iron, magnesium, manganese, phosphorus, potassium,
    selenium, sodium, zinc;
  - cholesterol and choline;
  - essential amino acids;
  - fats: mono-, poly-, saturated and trans; omega-3 (ALA, DHA, EPA, total); omega-6;
  - fiber, starch, sugars and added sugars;
  - folate;
  - vitamins A, C, D, E and K;
  - water.
- **Body:** Scale Weight (with fat percent), Weight Trend, Expenditure, Steps.
- **Body Metrics:**
  - bust, chest, hips, neck, shoulders and waist;
  - left and right ankle, bicep, calf, forearm, thigh and wrist;
  - visual body-fat assessment.
- **Muscle Groups:** sets and volume for 22 muscles.
- **Exercises:** 1-RM, 3-RM, 10-RM, total volume, best-set volume, heaviest weight, total
  reps, best-set reps, total and best-set duration, total sets.
- **Food library:** Recipes, Custom Foods, Favorites, History.
- **Training Programs** (cycles, deload, colour, icon) and **Workouts** (exercise, notes,
  per-set type, RIR and rest).
- **Day flags and notes:** Fasting, Partial Logging, Micronutrient Goals, Food Log Notes,
  Workout Log Notes.
- **User Profile:** sex, birthday, height, activity level, sessions per week, lifting
  experience, cardio experience, athletic pursuits, prediction style.
- **Nutrition Program Settings:** per-weekday targets, expenditure and expenditure
  calculation mode, one row per program update.
- **Weight Goals:** goal weight, goal rate in % of bodyweight per week, start and end,
  checkpoints, starting and ending scale and trend weight.
- **Workout Settings:**
  - previous reference, propagate changes, RIR tracking;
  - superset auto-scroll, exercise auto-next, keep-alive, workout timer;
  - bodyweight contribution;
  - rest timers: between exercises, between left and right sets, and per compound upper
    and lower;
  - warm-up automation and schemes;
  - expand rep range, weight match, deload, exercise assessment, hide completed sets;
  - sound and vibration.
- **Gym Profiles:** equipment and weights, allowed and disallowed exercises, bumper and
  mixed-unit plates, offset weight.
- **Custom Exercises:** type, trackable metric, laterality, primary and secondary muscles,
  joint actions, resistance and support equipment, bodyweight contribution, range of motion,
  stability, alternative names.

### Seen in MacroFactor

- **Nutrition Overview:** Yesterday, 1 week, 1 month, 3 months, 1 year. Each nutrient has a
  bar against its target, with a target marker and a percentage.
- **Contributors:** each food's share of a nutrient.
- **Nutrient Timing:** calories across the day.
- **Strategy-based targets.**
- **Shortcuts:**
  - "Log by JSON";
  - "Find Recent Food";
  - a today-summary JSON: `consumed` per nutrient, and `remaining` as minimum, target and
    maximum.
- **Apple Health:** writes nutrients, weight and workouts.

### Beyond: seeds

- **Speed:**
  - a repeat food in 3 taps or fewer;
  - a set in one tap, prefilled from last time;
  - meal copy across days;
  - suggestions by time of day;
  - cold launch to logging in under 1 second.
- **On-device intelligence:** barcode and label scanning; photo and text meal logging with
  confirmation.
- **Training intelligence:**
  - RIR-based autoregulated progression;
  - fractional volume per muscle;
  - recovery-aware weekly volume, using sleep, HRV and resting HR from Apple Health;
  - PR detection;
  - plate and warm-up calculators;
  - supersets;
  - rest timer as a Live Activity;
  - a Watch workout app with heart rate.
- **Agent features:**
  - a weekly review with at most three ranked suggestions, each with evidence and a
    falsifier;
  - program generation and adjustment as proposals;
  - stall and plateau diagnosis;
  - deload detection;
  - n=1 experiments.
- **A food database that beats MacroFactor's on coverage and accuracy:** USDA FDC, Open
  Food Facts and FatSecret, with source shown and community or user corrections.
- **Full Apple Health read and write**, widgets, and App Intents covering MacroFactor's
  Shortcuts and more.
- **Migration in:** import MacroFactor's export (every sheet above), Apple Health history,
  and Hevy and Strong exports.
- **A developer platform:** MCP server, OpenAPI, tokens and webhooks, full-fidelity
  JSON/CSV/xlsx export, stable IDs, UTC plus timezone, and idempotent writes. Ali's
  Ascension dashboard will consume it.

## How to work: survive context resets

- **First session:**
  - Run the existing test commands for your area and the iOS build, and record a baseline.
  - Keep your ledger (docs/ledger/logic.md or docs/ledger/app.md): current milestone, next
    three steps, risks, and exactly how to resume. Update it after every milestone, so a
    fresh context can continue from the ledger alone.
- **Priority order** across both agents (each takes the items in its own area; re-rank in
  PARITY.md when evidence says so):
  1. Backend foundation: Postgres, migrations, auth with Sign in with Apple, sync,
     docker-compose. Minimal but right, because everything else sits on it.
  2. Training core: exercise library with muscles, joint actions and equipment; performed
     sessions with sets, reps, load, RIR and set types; rest timers; history; e1RM; volume
     per muscle.
  3. Agent core: the proposal, review, accept and undo model; the audit log; the MCP server
     and scoped tokens; the first agent features on top of the training data.
  4. Programs, progression and autoregulation.
  5. Nutrition depth: full micronutrients, food database strategy, adaptive expenditure
     and coaching parity, and the MacroFactor import.
  6. Apple Health, widgets, App Intents, Live Activities, Watch.
  7. Analytics and the optimizer tools: experiments, correlations, custom metrics.
  8. Public readiness: privacy, account lifecycle, docs/RELEASE.md.
  9. Polish, accessibility, performance.
  10. The rest of Beyond.
- **For each milestone:**
  1. Write a design note.
  2. Write tests first.
  3. Implement.
  4. Run the unit tests and simulator UI tests with Xcode 26.2.
  5. Take screenshots in light and dark, on a small and a large phone, at the largest
     Dynamic Type size. Look at every one of them.
  6. Upload a TestFlight build.
  7. Update PARITY.md and the ledger.
  8. Commit and merge.
- **Quality bar, per feature:**
  - zero failing tests and no new warnings;
  - VoiceOver labels on everything;
  - correct units, timezones and daylight-saving handling;
  - no data loss when offline;
  - 60 fps scrolling;
  - each user's data isolated in every query.
- **Algorithms** (expenditure, trend, progression, readiness) are checked against simulated
  ground truth, with their error documented.
- **The project is a classic .pbxproj.** Register files correctly and build after every
  change. Move to XcodeGen or Tuist only if you record why in DECISIONS.md.
- **After parity, keep going.** Do a competitor teardown each cycle, re-audit with fresh
  eyes, fix, and ship again.

## Stopping

Stop only when Done is met, or when every remaining item in your area is blocked on
QUESTIONS_FOR_ALI.md or on the other agent. If you're blocked on the other agent, review
their work, improve tests or polish your own area while you wait, and keep checking your
inbox. End with a summary: what's implemented, tested and on TestFlight;
build numbers; screenshot paths; and open questions.
