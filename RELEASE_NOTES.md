# RetreatUI v1.1.7-beta.17

This prerelease is a focused performance and secure-frame safety hotfix. It does not change the established HUD layout.

## Class HUD performance

- Stops legacy class-helper polling from running for unrelated classes.
- Cultist Wago mechanics polling is active only while the Cultist Class HUD is active.
- Tinker healer-pet polling is active only while the Tinker Class HUD is active.
- Guardian reminder polling is active only while the Guardian Class HUD is active.
- Guardian banner tracking no longer listens to `COMBAT_LOG_EVENT_UNFILTERED` for every character; the combat-log listener is registered only for an active Guardian HUD.
- Idle helper drivers unregister their events instead of continuing to process aura/combat events in the background.

## Secure-frame / combat taint safety

- RetreatUI generic cleanup no longer includes Blizzard `PlayerFrame`, `TargetFrame`, or party unit frames in its cleanup candidates.
- Protected frames are rejected before RetreatUI calls `SetAlpha`, `EnableMouse`, `Hide`, or other visual/mouse mutations.
- Native class-resource cleanup now applies the same protected-frame boundary.
- Old persisted generic cleanup entries for Blizzard unit frames are discarded instead of being re-applied.
- ElvUI remains responsible for Blizzard unit-frame visibility; RetreatUI cleanup is limited to safe, unprotected Ascension/CoA resource containers.

## Validation

- Adds CI regression checks preventing protected Blizzard unit frames from returning to the cleanup allow-list.
- Adds CI checks for the beta.17 class-driver gate and protected-frame early-return rules.

## Testing notes

A full `/reload` is required after installing this build. A frame that was already tainted earlier in the current WoW session cannot be made untainted by changing Lua code after it has loaded.

Please specifically test:

- FPS/frame pacing with `RetreatUI_Classes` enabled.
- Entering combat, changing target, party/raid transitions and secure actions without the `RetreatUI prevented the call of the secure function 'UNKNOWN()'` warning.
- Your normal class HUD/resource tracking to confirm no visible layout regression.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
