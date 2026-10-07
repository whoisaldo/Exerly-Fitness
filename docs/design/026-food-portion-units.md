# Food portion units

N03 uses Core's USUnits, volume basis and Serving.quantity helpers. The app only
chooses the displayed measure and retains entered text; Core converts and validates.

New U.S. entries start in ounces, or U.S. fluid ounces when the food has a volume
basis. Metric accounts start in grams or milliliters. Repeating or editing an
entry keeps its original measure and exact portion. Named portions remain
available, including the one saved with a historical entry.

Changing the measure first previews the current portion. It converts that exact
weight into the chosen display unit without changing nutrients. Keep an exact
weight anchor while the displayed amount is untouched, so repeated switching
does not accumulate rounding. Invalid text blocks switching and stays visible.

Unit portions use ordinary Serving snapshots, such as one ounce with its Core
weight. This preserves the chosen measure across offline save and relaunch.
Volumes require the food's recorded density; never invent a density. Show an
estimate label when that recorded basis is assumed.

Use a selection sheet for measures, numeric entry with meaningful increments and
presets, and the existing portion summary. At accessibility sizes, every choice
shows its full label and selected state. Nutrients continue using kcal, g, mg and
mcg, independent of a food's mass or volume measure.

Test U.S. and metric defaults, fractional named portions, comma decimals, repeated
unit switching, original optional quantity, density, invalid drafts and entry
corrections. UI checks must switch ounces, grams, servings and fluid ounces, then
save offline, relaunch and inspect the synced export. Capture both appearances
and largest type before release.
