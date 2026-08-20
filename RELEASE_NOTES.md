# RetreatUI v1.1.7-beta.49 - Native Profile Packs

This prerelease replaces the fragile compressed reference-profile runtime with two deterministic native CoA profile packs.

## Profile runtime

- Retreat Focus and Retreat Edge are now built as native Ascension-compatible ElvUI profile tables.
- The compressed Focus/Edge payload chunks are no longer loaded at runtime.
- This removes the `unfinished long string` failure reported from `PayloadChunks/e_e1440_1.lua`.
- Profile switching no longer depends on a newer Retail ElvUI Distributor decoder.
- Focus and Edge remain separate ElvUI profiles and ACTIVE reflects the profile actually selected by ElvUI.

## Retreat Focus

- Compact, centered combat layout.
- Smaller player/target frames with tighter spacing.
- Compact party, boss and focus frames.
- Smaller minimap, chat footprint, action buttons and TurboPlates aura icons.
- Dark restrained unit-frame presentation intended to minimize visual clutter.
- Compact Details rows and meter scale.

## Retreat Edge

- Significantly larger player/target frames with wider separation.
- Larger party, boss, focus, raid and target-of-target frames.
- Larger minimap, chat footprint, action buttons and TurboPlates aura icons.
- Class-colored ElvUI health frames for a more information-rich presentation.
- Wider nameplates and more generous nameplate overlap spacing.
- Larger Details rows and meter scale.

## UI scale safety

- RetreatUI does not change WoW's global `uiScale` or `useUiScale` values.
- ElvUI profile activation snapshots and restores the existing scale CVars.
- Profile-level auto/custom UI-scale fields are stripped from the native packs.
- The RetreatUI workspace remains at native frame scale 1.0.

## HUD retained

- HUD configuration stays inside the main RetreatUI window.
- Search by spell name or Spell ID.
- Choose Main Ability, Buff / Proc, Utility, Defensive or Target Debuff.
- Drag spells into exact action-bar-style slots.
- Create multiple custom Horizontal or Vertical HUD bars.
- No prebuilt class WeakAura package is installed.
- No custom WeakAuras trigger Lua and no direct WeakAuras insertion API.

## Safety

- Professional Audit remains the canonical CoA spell/effect identity source.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
