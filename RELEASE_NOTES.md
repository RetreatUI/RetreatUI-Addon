# RetreatUI v1.1.7-beta.19

This prerelease targets the remaining large CoA frame-time spikes reported with `RetreatUI_Classes` enabled. The established HUD layout and class curation are unchanged.

## WeakAuras runtime performance

- Removes RetreatUI's synthetic global `UNIT_POWER_FREQUENT` wake-up that previously called `WeakAuras.ScanEvents()` every 0.12 seconds.
- Native Ascension resource polling now uses the RetreatUI-only `RETREATUI_RESOURCE_PULSE` event at a lower cadence and only for classes that actually expose a native custom resource.
- Main, Utility, Proc, State and Target WeakAuras no longer all react directly to raw `UNIT_AURA` storms.
- Adds a debounced RetreatUI event coordinator so combat event bursts produce at most one short refresh batch instead of multiple complete HUD recalculations.
- Player aura updates are routed only to player-owned HUD elements; target aura updates are routed only to target debuffs.
- Cooldown and usable-state events are collapsed into the RetreatUI row refresh path.

## Runtime state caching

- Main/Utility rows, Proc tracking, Class State tracking and Target Debuffs now cache their final snapshots until the relevant game state changes.
- This prevents repeated 40-aura scans and repeated spell cooldown/usable queries when several WeakAura regions refresh during the same event burst.
- Native custom-resource snapshots use a short shared cache so bar/segment displays do not independently rescan Ascension frames during the same update.

## Combat-log isolation

- The Hellfire Imp runtime no longer listens to `COMBAT_LOG_EVENT_UNFILTERED` on every CoA class.
- Its combat-log listener is enabled only while Knight of Xoroth is the active class.
- Explicit resource WeakAuras no longer wake directly on every combat-log event; relevant Knight resource changes are debounced through a RetreatUI-specific refresh event.

## Preserved fixes

- beta.18 chat ownership changes remain intact. RetreatUI still does not force-show, dock, undock or close chat tabs.
- beta.17 protected-frame / secure-taint protections remain intact.
- No HUD coordinates, icon sizes, class curation or target-aura policy were changed in this performance build.

## Testing notes

Close Project Ascension completely after installing this build and start it again.

Please specifically compare frame pacing with `RetreatUI_Classes` enabled on Sun Cleric and Templar in a dungeon or battleground. Also verify normal resource updates, cooldowns, procs, class-state icons and Knight of Xoroth Hellfire Imp tracking.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
