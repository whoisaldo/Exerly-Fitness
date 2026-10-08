# Multi-food meal logging

N04 uses the published NutritionStore plate contract. Build a meal from Add food,
select several saved or database foods, review each portion and the combined
Calories/macros, choose a meal and date, then log once. No food entry is persisted
while selecting or editing. Cancelling a nonempty meal asks before discarding.

New portions use the account's U.S. default. A recently logged food keeps its
previous measure and exact portion. Each row retains the reviewed food snapshot.
Portion edits use NutritionEntryDraft and the shared measure selection, including
exact anchors when switching units. Editing and removing one row leaves the
others unchanged. Selecting the same food twice creates two deliberate rows.

Core performs every conversion and total. A disposable in-memory NutritionStore
validates each proposed plate and supplies its summary and missing-value counts.
It never touches the account store or sync queue. The final confirmation calls
the real store's log([PlateItem], on:meal:at:) exactly once. A successful save is
cached to prevent repeated confirmation from creating duplicates. A failed save
retains all rows and the date, meal and time.

The review opens with the combined nutrition summary, then food rows with an
editable portion and remove action. One persistent Add foods action leads back
to selection. Empty state explains the next action. Purple/pink identity and
default dark appearance stay unchanged. Small phones and largest type must keep
food names, quantities and actions readable.

Verification covers draft isolation, exact U.S./metric portions, unknown versus
zero, cancellation, row edits/removal, a closed-store failure, and duplicate
confirmation. A native journey adds two foods, edits one, cancels an edit, logs
offline, relaunches, reconnects and checks exported snapshots and exact weights.
Capture default light/dark and largest type before release.

## Verified implementation, 2026-10-07

Core 308, API 261, 191 active hosted tests and a device build pass on the
combined scanner and meal source. Both native meal journeys pass in default
light, default dark and largest dark. Exports retain 70.8738078125 g for
2.5 oz and 68.01911799375 g for the synthetic liquid's 2.5 fl oz. The review
rounds only its secondary gram label. Zero sodium stays zero and missing
protein stays unknown. Cancelling selection or portion edits writes nothing.

All 47 final captures in artifacts/design/plate-integrated-light, -dark and
-ax were inspected. The public MacroFactor comparison is
artifacts/design/contact-review/a12-meal-reference.png. The first selection
header pushed foods too far down on a small phone. It is now a short caption
with a toolbar create action. The selected meal fits, food additions have a
visible check, and large type uses a single column. The offline test's scroll
helper now avoids the fixed footer and taps footer actions directly. Original
failed runs remain in the artifacts.

Ali's subsequent usability direction puts barcode scanning before search and
manual entry. The next milestone will simplify the Add food entry point and
the scanner. That work is separate from this verified meal draft.
