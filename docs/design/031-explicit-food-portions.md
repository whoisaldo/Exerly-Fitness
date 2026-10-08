# Choose a label portion directly

Barcode lookup already opens a food's portion review, and repeat logging
preserves the last exact amount. A first use still starts in ounces or U.S.
fluid ounces. A supplied named serving should be directly selectable from
that review, without opening a measure menu and changing the quantity again.

Offer clear buttons for the food's published servings and recipe portion.
A tap explicitly chooses one of that provided portion. Do not parse its name,
infer weights, or silently replace a previous portion. Keep the current
ounces or explicit metric preference until the person chooses a portion.
Foods without supplied portions retain the existing amount controls.

The draft calls NutritionStore.preview for the chosen serving and quantity.
All weight and nutrient arithmetic stays in Core. A selection only edits the
draft; Log remains the only diary write. Existing entry nutrition corrections,
unknown nutrients, cancellations and exact old weights must remain intact.

Verify a supplied bar, a fractional label serving, a recipe portion, an edited
entry and an invalid previous number. Cancellation writes nothing. A saved
selection must reopen with the exact serving and quantity. Capture the direct
choice, resulting summary and offline relaunch in light, dark and largest text.

The first visual review found the nutrient summary below the amount and meal
controls. Move it immediately below the food name. Keep meal and date in the
header while the amount controls scroll. Display a supplied serving's weight
in ounces for U.S. accounts, with at most two decimals; stored precision is
unchanged. Nutrition details and correction stay available below the meal.

Comparison uses MacroFactor's public App Store screenshots and its
[food logging guide](https://help.macrofactorapp.com/en/articles/215-how-to-log-food-in-macrofactor).
That guide puts nutrition before serving controls. Exerly now follows the same
reading order, with direct published-portion buttons. MacroFactor additionally
shows impact on targets and integrates more logging actions with its keypad.
Those remain follow-up work; this change does not claim full parity.

The final liquid-relaunch review caught a synthetic fl oz measure appearing
as a label portion. Exclude recognized measurement-unit servings from the
published choices. A dedicated regression preserves the exact stored weight
and only offers the actual supplied Scoop portion after reopening.
