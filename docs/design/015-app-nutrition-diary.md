# A7: the offline nutrition diary

App owner, 2026-10-06. Build on A6 account isolation, sync, proposals and exports.
Use NutritionStore and AccountAPI contracts from Logic. Keep Exerly's purple/pink
theme, neutral surfaces and existing navigation. No food, target or serving
calculations belong in the screens.

The diary opens the selected account's current local date. Previous, next and
calendar controls change that date without changing when an entry was eaten.
Show Core's day summary, the targets in force, meal sections and the day's
logging status. Unknown nutrients stay unknown. A partial log is labelled as
partial and never presented as a complete intake. Empty, fasting and complete
are distinct states. Notes save locally and survive relaunch.

Add food opens local recents and favorites immediately. A recent food can be
selected, reviewed with its previous amount and logged within three taps from
the diary. A submitted search calls AccountAPI.searchFoods; typing does not
consume the remote search budget. Barcode scanning and typed digits use the
same account API. Show busy, unavailable and not-found outcomes separately,
with a manual path. Show the food source and required database attribution.
Unsupported volume labels must not silently become gram-based foods.

The amount screen shows the food, source, selected meal/date/time, grams or a
named serving and decimal quantity. Preview nutrients using NutritionStore.preview. Save only after validation;
keep the draft when a write fails. Comma decimals and unchanged precision use
the existing app input conventions. Logging a database food does not require
favoriting it. Editing a saved food cannot rewrite earlier entry snapshots.

Manual food entry supports energy, macros and every nutrient in Core, grouped
by Nutrient.group with the unit next to each input. A blank means unknown, and
an explicit zero stays zero. Labels entered per serving require its known
weight and Core's basis conversion. Use Food.per100g(fromLabel:servingGrams:) for that conversion. A user can save a reusable food or just log an entry.

Entry review supports editing amount, meal and eating time. Check that the
stored entry still equals the reviewed version before saving or deleting; a
sync update must not be silently overwritten by a stale screen. Deletion has
an explicit confirmation and an undo that cannot overwrite a later change.
Meal/day copy calls Core's atomic copy operation and previews source date,
destination date, meal and item count. Guard duplicate taps while saving.

Composition adds NutritionStore to sync, agent proposal hosts, supported kinds
and account export. Food and meal proposals show their food, grams, nutrient
values, source, date/meal and complete before/after records. Accept and undo
remain AgentStore operations; do not add a second decision path. An account
switch closes its persistence and clears any food-search or editing draft.

Replace the legacy diary with NutritionStore. Logic confirmed that only test
rows exist and no bridge is needed. Leave the legacy sync queue running so
pending entries can reach the server, and keep legacy server rows in account
exports. Do not copy or migrate rows in screens. Ali's real history will enter
through the MacroFactor and Health importers.

Tests precede each new store composition or editing behavior. Use real Core
stores for account isolation, export, unchanged snapshots, stale-edit refusal,
unknown nutrients, precise portions and proposal accept/undo. Real-server UI
journeys cover local manual logging, submitted search, barcode hit/miss, edit,
copy, deletion/undo, partial/fasting flags, notes, offline relaunch and reconnect.
Verify stored server records, not just success labels. Count the repeat-food
taps. Inspect light/dark on small/large phones at largest text, including every
confirmation and all nutrient input groups. Run the full suites and device
build before an Ali-only internal TestFlight release.

Later milestones add recipes, coaching/check-ins, overview/timing/contributors,
Apple Health and Shortcuts using Logic's published interfaces. This milestone
must keep their data and proposal kinds intact without claiming those screens
are complete.
