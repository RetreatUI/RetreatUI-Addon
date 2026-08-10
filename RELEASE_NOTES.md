# RetreatUI v1.1.7-beta.12

This prerelease applies the live-tested State position, moves player target debuffs back to ElvUI, and removes the retired secure Buff Manager runtime from the shipped load path.

## Exact State / stance / form placement

- The shared State Dynamic Group is now fixed at X Offset -159 / Y Offset -3.
- The group remains SCREEN/CENTER anchored and uses one global rule for every CoA class.
- Every actual State / stance / form icon remains exactly 38x38 with child X Offset 0 / Y Offset 0.
- Reinstalling WeakAuras still rebuilds the current class State tree so older offsets cannot survive.

## Target debuffs belong to ElvUI

- The class `Target` WeakAura group is retired and removed during WeakAura reinstall.
- RetreatUI no longer renders target debuff bars/icons in its HUD.
- The RetreatUI ElvUI profile enables Target Debuffs with filter priority `Blacklist,Personal`, so only the player's own non-blacklisted target debuffs are shown by ElvUI.
- The WeakAura class package is now Resource, Main, Utility and State; target debuffs are owned by ElvUI.

## Secure runtime cleanup

- `Core/BuffManager.lua` is no longer loaded by RetreatUI.
- The retired Buff Manager created SecureActionButtonTemplate frames, changed secure spell attributes and installed override bindings on login even when it was not part of the new installer.
- Removing it from the load path eliminates that unnecessary secure-frame/override-binding taint surface.
- The file remains in the repository for reference; it is simply not executed by the addon.

## Installer

The clean TBC-style installer remains limited to ElvUI, Guardian Macros (Guardian only), Details, TurboPlates and WeakAuras, plus Welcome/Reload navigation pages.

`RetreatUI - General` continues to own Trinkets, Buffs & Procs and Racials.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
