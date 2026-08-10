# RetreatUI v1.1.7-beta.13

This prerelease splits the Buff Manager out of the RetreatUI core into its own optional addon while preserving the beta.12 HUD, State and ElvUI target-debuff rules.

## RetreatUI_BuffManager

- New separate addon folder: `RetreatUI_BuffManager`.
- Hard dependency: `RetreatUI`.
- Author remains `Retreat`.
- The existing Buff Manager implementation is moved out of `RetreatUI/Core` and is no longer shipped as dead core code.
- The addon is disabled by default so secure buff buttons and override bindings only exist for players who explicitly enable the Buff Manager addon.
- It keeps the existing compact buff bar, assignment manager, equivalent-buff coverage, Smart Buff keybind support and class-specific buff rules.

## Core separation

- `RetreatUI` itself does not load or own the Buff Manager runtime.
- The clean TBC-style RetreatUI installer stays limited to ElvUI, Guardian Macros when applicable, Details, TurboPlates and WeakAuras.
- Target debuffs remain owned by ElvUI with `Blacklist,Personal`.
- State / stance / form placement remains the beta.12 global rule at X -159 / Y -3, with 38x38 child icons at X 0 / Y 0.

## Packaging

The release ZIP now contains three independent WoW addon roots:

- `RetreatUI`
- `RetreatUI_Classes`
- `RetreatUI_BuffManager`

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
