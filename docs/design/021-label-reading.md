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
  per-serving column after it. The first column is read. Energy in kJ and
  kcal: kcal wins, else kJ ÷ 4.184. Salt becomes sodium: 1 g of salt is
  400 mg of sodium.

A label counts as EU-style if it mentions per 100 g or 100 ml, kJ or salt.

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

Synthetic US and EU labels with the misreads above, a drink in kJ per 100 ml,
and non-label text. Real labels vary more. Every reading goes to a review
screen, and the unread and approximated lists say where to look.
