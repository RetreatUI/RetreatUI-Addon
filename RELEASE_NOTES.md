# RetreatUI v1.1.7-beta.47 - Visual Scale Fix

This prerelease keeps the beta.46 integrated HUD workflow but corrects the visual scale of the RetreatUI workspace.

## Visual scale correction

- RetreatUI no longer looks artificially zoomed out on 1080p-class UI canvases.
- The global WoW UI scale and ElvUI UI scale are not modified.
- Only the RetreatUI main workspace receives a local visual scale correction.
- Fonts, navigation, buttons, profile cards and HUD slots are visually larger and easier to read.
- The workspace keeps a large editor footprint while remaining inside the visible screen area.

## HUD retained from beta.46

- Search by spell name or Spell ID.
- Choose Main Ability, Buff / Proc, Utility, Defensive or Target Debuff.
- Drag spells into exact action-bar style slots.
- User-created bars with custom slot count and Horizontal / Vertical orientation.
- Empty slots remain empty.
- Existing HUD icons can be reordered between slots.
- Source/cooldown IDs remain separate from applied aura/effect IDs.

## Profiles

- Retreat Focus and Retreat Edge remain the two complete UI profile choices.
- ElvUI, TurboPlates and Details remain separate from the user-built WeakAuras HUD.

## Safety

- Professional Audit remains the canonical CoA spell/effect source.
- No custom WeakAuras trigger Lua.
- No direct WeakAuras insertion API.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
