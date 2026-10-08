# Save a dish once, log a portion later

A beginner should be able to scan or search for ingredients, set how many
portions the dish makes, and log it again without rebuilding the meal.
Recipes belong beside saved foods. Offer Create recipe from the library,
then keep ingredients and the portion summary above optional preparation.

Use the existing barcode-first food picker in selection mode. Selection
changes only a draft. Review and edit every ingredient's amount before
saving. Support removal and explicit reorder actions that work with
VoiceOver. U.S. accounts use ounces and fluid ounces; macros stay grams.

Explain two independent ways to portion a dish. A serving count makes equal
shares. An optional finished weight is for weighing a cooked portion. Never
describe the raw ingredient sum as a measured cooked weight. If no finished
weight is supplied, label that basis plainly and recommend using servings.

The recipe header shows nutrition for one serving when a count is supplied,
otherwise for the whole dish. Details disclose ingredients, their amounts,
preparation and the weight basis. Editing a recipe updates future portions;
existing diary snapshots stay unchanged. Recipe edits must reject a stale
review or an account switch, and cancellation must write nothing.

Use Core's Food.recipe, withIngredients, recipeServing and NutritionStore
preview/saveFood. The app parses fields and presents results; it does not
calculate totals. Preserve exact unchanged weights even when display values
round. Core's missing-nutrient coverage issue is reported in to-logic.md and
must be resolved before claiming recipe totals are complete.

Tests cover a cancelled draft, fractional ounce input, cooked yield and equal
servings, editing/reordering/removing ingredients, relaunch, stale reviews,
account changes, unknown versus zero, exact export and unchanged history.
Capture the empty builder, ingredient amounts, summary, saved detail and
editing in default light/dark and largest text before release.

Public references: MacroFactor's [recipe creation](https://help.macrofactorapp.com/en/articles/6-create-and-add-a-custom-recipe)
and [multiple servings](https://help.macrofactorapp.com/en/articles/223-tips-for-creating-recipes-for-dishes-comprised-of-multiple-servings)
guides. Both distinguish equal portions from a weighed finished dish. Exerly
will accept finished weight in ounces for U.S. accounts, reuse the food
picker and keep the portion review in the same draft. Importing recipe links,
photos and AI descriptions remains separate work.

## PR checkpoint

The draft and screens are implemented. Four new hosted tests pass, within
214 active hosted passes and one credential skip. The native recipe journey
is written but not run, and recipe visual review is pending. Core's recipe
completeness P1 is unresolved. This is a draft PR, not a recipe release claim.
