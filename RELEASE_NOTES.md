# RetreatUI v1.1.7-beta.18

This prerelease directly addresses the live chat-overlap and frame-pacing reports from CoA testing. It does not change the established HUD layout.

## Chat ownership / overlapping tabs

- Removes the old runtime behavior that force-showed `ChatFrame1` and companion chat regions.
- Removes target-change chat refreshes entirely.
- RetreatUI no longer docks, undocks, closes, hides, shows or repositions Blizzard/ElvUI chat frames.
- The historical Loot/Trade cleanup is permanently replaced with a state-only no-op.
- Adds one safe login recovery pass using Blizzard's own `FCF_DockUpdate()` so existing dock visibility is recalculated without deleting tabs or changing dock membership.
- ElvUI and Blizzard are now the sole owners of chat tab visibility and docking.

## ElvUI refresh storm fix

- The old Pyromancer/Details compatibility driver no longer runs on `PLAYER_TARGET_CHANGED` or `PLAYER_ENTERING_WORLD`.
- Removes the repeated delayed 0.10 / 0.50 / 1.50 second refresh passes.
- Pyromancer Heat filtering is now static profile data only.
- Removes the fallback to `ElvUI:UpdateAll(true)`, which could refresh action bars during normal gameplay and feed repeated `ActionButton_UpdateOverlayGlow` work.

## RetreatUI_Classes frame pacing

- Removes `ACTIONBAR_UPDATE_COOLDOWN` from the shared AdvancedHUD event driver.
- Removes `UNIT_POWER_FREQUENT` from the shared AdvancedHUD event driver.
- Cooldown events now update only cooldown timers and usable-state glows instead of rescanning up to 40 player auras and rebuilding both HUD rows.
- Power events no longer scan all player auras for classes that do not own a custom resource.
- `UNIT_AURA` remains the owner of proc/buff state, while the existing lightweight timer remains the owner of countdown text.

## Testing notes

Close Project Ascension completely after installing this build and start it again.

Please specifically test:

- Switching between General, Party and custom chat tabs and creating/selecting new tabs without two chat frames rendering on top of each other.
- Sun Cleric and Templar frame pacing in town and inside a dungeon with `RetreatUI_Classes` enabled.
- Whether the repeated `ActionBarButtonSpellActivationAlert` / `ActionButton_UpdateOverlayGlow` Lua error stops occurring during normal target changes and combat.
- Normal class HUD cooldowns, procs and resources for visual regressions.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
