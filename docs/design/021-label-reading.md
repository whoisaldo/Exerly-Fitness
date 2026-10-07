# M13: reading a nutrition label from the camera

Owner: logic agent. Status: built, 2026-10-06. PARITY N15, and the Beyond seed
"barcode and label scanning".

The app runs on-device text recognition (Vision) over a photo of a label and
passes the lines, top to bottom, to `NutritionLabel.read`. ExerlyCore turns
them into nutrients the person reviews before saving a custom food. Nothing
leaves the phone.

## Formats

- **US Nutrition Facts:** amounts per serving, "Serving size 2/3 cup (55g)",
  calories, then nutrients with % Daily Value, which is ignored.
- **EU-style declarations:** amounts per 100 g or per 100 ml, often with a
  per-serving column after it. Energy in kJ and kcal: kcal wins, else kJ ÷
  4.184. Salt becomes sodium: 1 g of salt is 400 mg of sodium.
- **Australian and New Zealand panels:** per serving first, then per 100 g.
- **Canadian bilingual panels:** "Nutrition Facts / Valeur nutritive", the
  serving as "Per 1 bar (50 g) / pour 1 barre (50 g)", and nutrients named in
  both languages ("Fat / Lipides 8 g"). The English serving is kept.

The first column is read, and the label's own declaration says what it is
for: whichever comes first of an amount per serving ("Amount per serving",
"Per 1 bar (50 g)") and one per 100 g or ml. A "Nutrition Facts" or "Valeur
nutritive" title counts as per serving only when nothing more explicit does,
so "Nutrition Facts" over "Per 100 g" is per 100 g. Only lines
that name no nutrient count, so "Carbohydrate 100 g" isn't a declaration, and
"Serving size 1 cup (100 g)" is a serving. Without a declaration, a serving
size means per serving, and only then do kJ or salt suggest per 100 g. Energy
units used to decide it, so a US-style label printing kJ was read per 100 g
and logged half its energy (found by the app's tests).

## Reading

- **Clean-up.** Lowercase, decimal commas as points, and the usual misreads
  in amounts: a letter O for zero ("Og", "Omg"), and µg or ug as mcg.
- **Names.** Most specific first, so "saturated fat" is read before "fat",
  "added sugars" before "sugars", and "of which saturates" as saturated fat.
- **Amounts.** The first number after the name, with its unit, skipping
  percentages. "Includes 10g Added Sugars" puts the amount first, so the text
  before the name is tried too. When large type puts the number on its own
  line, as with "Calories" then "230", the next line is used.
- **Units.** Converted to ExerlyCore's: g, mg or mcg. Without a printed unit,
  the usual label unit is assumed.
- **"Less than."** A value printed as "<1 g" is read as its bound and listed
  in `approximated`, for the person to confirm.
- **Gaps.** Lines that name a nutrient without a readable amount are listed in
  `unread`. Text with no energy and fewer than two macronutrients isn't a
  label, and returns nil.

## To the food

`per100g` is the amounts for a label per 100 g, or the serving scaled by its
weight. A label per 100 ml, or a serving known only in millilitres, needs a
density, so it returns nil. The app then asks for the serving's weight, or
uses the volume basis (design 007 notes, `Food.volume`).

## Checked

Synthetic US, EU, Australian and bilingual Canadian labels with the misreads
above, per-serving labels with kJ or salt, a drink in kJ per 100 ml, and
non-label text. Real labels vary more. Every reading goes to a review
screen, and the unread and approximated lists say where to look.
