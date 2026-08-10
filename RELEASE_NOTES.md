# RetreatUI v1.1.7-beta.5

This prerelease fixes the remaining WeakAuras 5.21.2 icon crash seen on Conquest of Azeroth after beta.4.

## WeakAuras 5.21.2 icon compatibility

- Fixes `WeakAuras/RegionTypes/Icon.lua:642: attempt to perform arithmetic on field 'expirationTime' (a nil value)` when a cooldown-enabled icon is shown from a static custom trigger state.
- The reported locals showed the failing RetreatUI icon was already a valid `progressType = "static"` state. That means beta.4's timing-state validator was working, but the crash happened later inside WeakAuras' icon cooldown object.
- WeakAuras 5.21.2 `Icon:PreShow()` checks the cooldown object's duration before calculating `expirationTime - duration`. On the Ascension client, a static icon can leave that internal duration populated without a matching WeakAuras-owned expirationTime.
- RetreatUI now keeps real cooldowns as normal timed states, but converts otherwise-static ICON states at the final trigger boundary to a zero-duration timed state (`duration = 0`, `expirationTime = 0`). WeakAuras therefore clears/hides the cooldown safely before `PreShow()` and never enters the invalid subtraction branch.
- The compatibility layer only touches cooldown-enabled icon regions. Resource bars, segmented resources and target aura bars retain their normal static/timed semantics.
- Main, Utility, Buffs & Procs, class State icons, class counter icons and Trinkets are covered automatically.
- No HUD positions, class spell databases, tracked abilities or renderer ownership changed from beta.4.

## Existing WeakAuras HUD layout

- Buffs & Procs: X 0 / Y -83.
- Secondary/custom resources: X 0 / Y -118.
- Primary resource: X 0 / Y -152, 360x16.
- Main: X 0 / Y -183, 38px icons, 1px spacing.
- Utility: X 0 / Y -224, 32px icons, 1px spacing.
- Trinkets: `ElvUF_Player`, BOTTOMRIGHT to TOPRIGHT, X -17 / Y +1.
- Target debuffs and class states remain in their established RetreatUI locations.

## Testing note

Install beta.5 over beta.4, reload UI, then run the RetreatUI installer again. The Class WeakAuras HUD step should complete without the Icon.lua `expirationTime` crash. Existing partially-created beta.3/beta.4 RetreatUI WeakAuras are updated in place by the installer.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
