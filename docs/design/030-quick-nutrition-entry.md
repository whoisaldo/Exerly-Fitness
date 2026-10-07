# Quick Calories and macros

The diary and food picker keep barcode scanning first, search second. More
food options also offers Quick calories & macros for a known meal total.
There is no required name, weight or reusable food. The chosen diary day is
explicit, meal choices wrap, and one Log to meal button saves the whole portion.

Use the published NutritionStore.quickAdd contract. The app parses text and
Core validates and saves. Blank stays unknown, including when Calories are
missing but a macro is known. No macro-to-Calorie estimation. Repeated taps
cannot create a second entry. A changed account session cannot save an old
draft. Cancellation asks before discarding typed values.

Existing unweighed-entry presentation hides the nominal internal weight.
Totals remain editable through Entry nutrition. Quick adds never become
saved foods, recent foods or suggestions. Copy, move, deletion, undo, sync and
export use the same store and diary actions as ordinary entries.

Verify Calories-only and macro-only entries, explicit zero versus unknown,
malformed/negative input, double save, account changes, cancellation, editing,
offline relaunch and export. Capture default light/dark and largest text.

Public comparison, reviewed October 7, 2026:

[MacroFactor's Quick Add guide](https://help.macrofactorapp.com/en/articles/41-quick-add-calories-and-macros-to-your-food-log)
shows an optional name and basic macro entry. It also calculates Calories
from macros and can add several quick entries to a plate. Exerly currently
keeps missing Calories unknown and logs one whole portion. Those extra
capabilities remain follow-up work. Its public App Store screenshots remain
the reference for hierarchy and density.

Small-phone review showed the selected meal was below the initial fold. The
meal now appears in the header and in Log to Lunch, or the selected meal, so
the destination is visible while entering numbers. All arithmetic remains Core's.
