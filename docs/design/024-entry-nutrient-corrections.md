# Entry nutrient corrections

An entry can need different nutrition from its food label. Correct the nutrients
for the logged portion without rewriting the reusable food or older entries.
This extends N08 and keeps the source, food ID and serving snapshot intact.

## Experience

The food entry's portion summary opens a separate nutrient editor. Its header
names the food and exact portion. Calories and macros come first; the remaining
nutrients use the same expandable groups as custom foods. U.S. energy is Calories
in kcal, and macros remain grams. The screen uses Exerly's shared purple and pink
tokens, cards, type scale and numeric keypad in both appearances.

Apply changes the parent draft. Only Log or Save writes the entry. Cancelling the
parent discards the correction along with other unsaved changes. The diary and
portion summary identify edited nutrition. Future portion changes scale the
corrected snapshot through ExerlyCore, preserving the source attribution.

## Contract and safeguards

- Use `FoodEntry.editingNutrients` for the conversion to per-100-gram nutrients.
- Use `NutritionStore.preview` and `saveEntry` for validation and persistence.
- Preserve unknown nutrients as absent and explicit zero as zero.
- Opening and applying an unchanged editor preserves every original value.
- Reject a correction if the parent portion changed while its sheet was open.
- Reject Save if a newer synced entry replaced the reviewed original.
- Do no nutrition arithmetic or networking in the app layer.

## Verification

Hosted tests cover fractional quantities, comma decimals, untouched values,
blank and zero nutrients, invalid input, stale drafts, provenance, library
isolation and repeating corrected entries. The UI journey cancels a correction,
then saves offline, relaunches, halves the portion and checks the server export
after reconnecting. Run it at default size and the largest accessibility size.

Review default light/dark and accessibility captures against the existing public
MacroFactor logger reference. Record defects and fixes in the app ledger, land
the passing piece, and release from a fixed commit without holding integration.
