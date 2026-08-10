# RetreatUI v1.1.7-beta.11

This prerelease locks stance/form icon geometry to the exact WeakAuras values used throughout RetreatUI and strips the CoA installer back to the same clean core-import flow as TBC.

## Exact stance / form icon rule

- Every State / stance / form WeakAura leaf is exactly 38x38.
- Every State / stance / form WeakAura leaf has X Offset 0 and Y Offset 0.
- There are no per-class or per-state icon nudges.
- The shared State Dynamic Group owns the lane placement; individual state icons never carry their own positional correction.
- Reinstalling the class WeakAuras deletes and rebuilds the current class State tree so stale offsets from earlier betas cannot survive.
- Validation fails if any State child is not 38x38 at X 0 / Y 0.

## Clean TBC-style installer

The installer now contains only the requested core imports:

- ElvUI
- Guardian Macros (Guardian only; the step does not exist on other classes)
- Details
- TurboPlates
- WeakAuras

Welcome and Reload remain as navigation pages. Party Trackers, Buff Manager, NPC Tracking, DBM, Game Settings and Ascension Cleanup are no longer installer pages.

## General WeakAuras

`RetreatUI - General` continues to own Trinkets, Buffs & Procs and Racials. Racials are not part of class Utility.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
