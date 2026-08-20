# RetreatUI v1.1.7-beta.46 - Integrated HUD Bars

This prerelease replaces the separate Tracker Builder workflow with a large integrated HUD workspace inside RetreatUI.

## HUD workspace

- HUD configuration now lives directly inside the main RetreatUI window.
- The workspace is substantially larger and resizable, with a dedicated sidebar and full editor area.
- Search is intentionally minimal: enter a spell name or Spell ID and only matching results are shown.
- Selecting a spell exposes its HUD behavior without exposing source/aura implementation details.

## Action-bar style HUD bars

- HUD bars are now slot-based like action bars.
- New bars choose a name, slot count and Horizontal or Vertical orientation.
- Default bars are `Main Rotation 1` and `Utility Bar 1`.
- Users can create additional bars such as Main Rotation 2, Utility Bar 2, Proc Bar or any custom name.
- Each bar controls icon size, spacing, scale and position independently.
- Empty slots are preserved instead of compacting active icons together.
- Search results can be dragged directly into an exact slot.
- Existing HUD icons can be dragged between slots; dropping onto another occupied slot swaps their positions.
- Bars can be moved as one unit through Unlock Mode.

## Tracker behavior

Each spell can be assigned one of these user-facing behaviors:

- Main Ability
- Buff / Proc
- Utility
- Defensive
- Target Debuff

RetreatUI continues to keep source/cooldown IDs separate from applied aura/effect IDs behind the UI.

## WeakAuras

- Each HUD bar generates a native WeakAuras group with explicit child positions per slot.
- Horizontal and Vertical bars preserve exact slot geometry.
- No prebuilt class WeakAura package is installed.
- No custom WeakAuras trigger Lua is generated.
- No direct WeakAuras insertion API is used.
- `/rui tracker`, `/rui builder` and `/rui hud` now route into the same integrated RetreatUI HUD page rather than opening separate configuration windows.

## Profile system

- Retreat Focus and Retreat Edge remain the two complete UI choices.
- ElvUI, TurboPlates and Details remain separate from the user-built HUD.
- The Details installation path is being kept on the CoA-compatible profile path instead of forcing an incompatible reference payload.

## Safety

- Professional Audit remains the canonical source for CoA spell/effect identity.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
