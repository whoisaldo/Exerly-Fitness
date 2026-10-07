# Native nutrition label capture

App implementation of Logic's published design021 and `NutritionLabel.read`.
N15 follows N03 food units. The serving conversion contract arrived during the
N08 release checks. The N08 release checks continue from a fixed commit.

## Flow

Open Scan label from Add food or the barcode fallback. Choose a photo or use the
camera. Request camera permission only after that action. A device without a
camera can choose a photo or enter the food manually. Denied camera access offers
Settings and the same alternatives.

Vision recognizes text on the device. ExerlyCore parses the lines. The person
reviews the food name, serving basis, Calories and nutrients before saving a
custom food. The existing food editor remains the manual path and keeps the
same numeric controls. No food or entry is saved merely by choosing a photo.

Show the label photo beside the review, with unread lines and values printed as
less than clearly called out. Missing values remain unknown. U.S. Nutrition
Facts labels use their printed serving and Calories in kcal. Imported metric
labels keep their printed basis. Ask for a serving weight when one is missing;
do not assume that milliliters equal grams.

The image stays in memory for this draft. Do not upload it, add it to exports or
save it to the person's library. Cancel releases it and discards the draft.

## Implementation boundaries

The app owns permission, photo selection, image decoding and Vision text
recognition. ExerlyCore owns parsing, unit conversion and food validation.
Use `NutritionLabel.read`, `LabelReading` and `Food.per100g(fromLabel:)`.
Bound image bytes and decoded dimensions, run recognition off the main thread,
and reject late results after cancellation or a newer photo selection.

## Checks

Use synthetic label images only. Hosted tests must run Vision on a generated
Nutrition Facts image, then check the parsed serving and nutrients. Test empty
and invalid images, unknown values, measured zero, cancellation and replacement.
UI checks cover selecting a photo, reviewing and correcting recognized values,
cancel without persistence, manual fallback, and offline save/relaunch/sync.
Capture default light/dark and largest text before release. Physical camera
quality remains a separate device check; simulator evidence does not claim it.

## Implementation and current verification

Vision recognition runs in a cancellable detached task. ImageIO bounds source
bytes and pixel dimensions, then decodes an oriented2400px thumbnail. Visual
rows are grouped before Core parses the recognized lines, preserving separate
amount and daily-value columns. System Photos loads through FileRepresentation
after checking its size. Camera availability also requires a video capture
device, because the simulator can advertise UIImagePickerController camera
support without one.

Six hosted tests pass, including actual Vision on synthetic labels and
cancellation races. Full hosted181active plus1credential skip, Core305, API260
and device build pass. Small-phone default light and largest-type dark UI
journeys pass through review, correction, cancel, offline save and relaunch.
The large iOS26 Photos grid requires a visible-center UI-test tap when its
remote accessibility element reports not hittable. This still uses the actual
system picker and recognizer. Full UI release verification follows.

The largest-type review initially split Calories across two columns. The
editor now uses one column, with complete headings. The original photo has a
visible View photo action. Choosing another photo cancels the pending read
before the system picker appears.
