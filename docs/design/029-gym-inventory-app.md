# Gyms and available weights

People should not have to translate a workout recommendation into the weights
their gym actually has. Training gets a Gyms & equipment destination with a
clear current gym, a short equipment summary and separate Edit and Use actions.
Saving a new place does not switch an existing workout or program.

The editor starts with a name and equipment. Weight inventories are optional
and grouped by equipment, behind direct links. Each weight keeps its entered
unit. New entries use pounds unless the person chose kilograms. A new bar uses
45 lb or an explicitly metric 20 kg. Plate quantities mean matching pairs.
There is no automatic unit conversion when reopening or changing a name.

Use the existing purple and pink design system, summary cards, labeled number
inputs, large selection controls and visible Save actions. At large text the
rows wrap vertically. Empty states explain that unlisted weights use standard
increments. A profile with only bodyweight remains useful.

Core owns validation, persistence, exercise eligibility and all calculations.
The app passes the active gym's increments to both workout preview and its
final start check. It filters exercise selection on request, with an explicit
All exercises option. Editing a profile that changed during sync requires
reopening it, so an old screen cannot silently overwrite a new inventory.

Verify offline save, unchanged mixed-unit weights, invalid input, stale edits,
relaunch, gym switching, archiving, recommendation wiring and account export.
Capture light, dark and largest text, including the weight editor. Compare
with the public MacroFactor Workouts equipment screens before release.

Limits: named profiles do not rewrite existing programs or sets. Core's
barbell recommendations use the bar minimum and smallest plate increment;
exact combinations and warm-up/plate calculators are separate follow-up work.

Public references reviewed on October 7, 2026:

- [MacroFactor gym profiles](https://help.macrofactorapp.com/en/articles/300-set-up-your-gym-profiles).
  The reference lists several places compactly and offers equipment presets.
  Exerly keeps Use visible and separates it from saving. Icons, presets,
  exercise overrides and per-workout gym selection remain follow-up work.
- [MacroFactor equipment settings](https://help.macrofactorapp.com/en/articles/390-how-to-change-equipment-settings-to-simplify-weight-recommendations).
  Its equipment overview shows available sizes beside each equipment type.
  Exerly's editor keeps weights in their original units and uses a compact
  inventory list, with a separate entry area and explicit plate pair counts.

Reference images are in artifacts/design/references/macrofactor-gym-profiles.png
and macrofactor-gym-weights.png. The public App Store workout screenshots stay
in that directory for the overall hierarchy comparison.

The fixed A14 release gate exposed hidden exercise navigation while searching
on the largest phone. Exercise search now keeps toolbar content visible on
iOS 17.1 and later, using Apple's searchPresentationToolbarBehavior. iOS 17.0
keeps its original presentation. The gym journey requires Close to be visible
and tappable while results remain filtered, then finishes archive/restore.
Reference: https://developer.apple.com/documentation/swiftui/view/searchpresentationtoolbarbehavior(_:).
