# RetreatUI v1.1.7-beta.4

This prerelease fixes the first live-install failure found after moving the Conquest of Azeroth HUD into WeakAuras.

## WeakAuras install hotfix

- Fixes `WeakAuras/RegionTypes/Icon.lua: attempt to perform arithmetic on field 'expirationTime' (a nil value)` during Class WeakAuras HUD installation.
- Ascension can expose custom auras with a positive duration but no usable expiration timestamp. RetreatUI now validates every generated WeakAura progress state before WeakAuras receives it.
- A state is only allowed to remain `timed` when both a valid positive `duration` and `expirationTime` exist.
- Incomplete timed states are converted to valid static states instead of being passed to WeakAuras' cooldown renderer.
- The safety layer covers Main, Utility, Buffs & Procs, class states, target debuffs, primary/custom resources, explicit counters and trinkets.
- No HUD positions, class spell databases, tracking selections or renderer ownership were changed from beta.3.

## Existing WeakAuras HUD layout

- Buffs & Procs: X 0 / Y -83.
- Secondary/custom resources: X 0 / Y -118.
- Primary resource: X 0 / Y -152, 360x16.
- Main: X 0 / Y -183, 38px icons, 1px spacing.
- Utility: X 0 / Y -224, 32px icons, 1px spacing.
- Trinkets: `ElvUF_Player`, BOTTOMRIGHT to TOPRIGHT, X -17 / Y +1.
- Target debuffs and class states remain in their established RetreatUI locations.

## Testing note

Run the installer again on the same class that failed in beta.3. The Class WeakAuras HUD step should now install without the `expirationTime` error. After a successful install, reload UI and verify the active class HUD normally.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
