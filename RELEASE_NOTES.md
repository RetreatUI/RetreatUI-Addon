# RetreatUI v1.1.7-beta.6

This prerelease fixes the remaining WeakAuras 5.21.2 `Icon.lua:642` crash after beta.5 by correcting the generated displays' progress source.

## WeakAuras progress-source fix

- The beta.5 crash locals still showed `progressType = "static"` on the rendered Icon even though RetreatUI had converted the custom trigger state to a safe timed zero-duration representation.
- WeakAuras 5.21.2 distinguishes between the trigger state and the region's selected `progressSource`. RetreatUI generated its custom-state displays with `progressSource = {1, ""}`, which does not provide WeakAuras with a concrete timer/number descriptor for these stateupdate triggers.
- RetreatUI now sets generated custom-state Icons and AuraBars to automatic state progress (`progressSource = {-1, ""}`). WeakAuras therefore reads `state.progressType` directly and dispatches to its normal timed/static progress paths.
- Combined with the beta.5 icon compatibility layer, ready/static cooldown-enabled Icons are represented as a zero-duration timed state and are now actually consumed as timed by the region, preventing the invalid `expirationTime - duration` subtraction in `Icon:PreShow()`.
- Real cooldowns retain their normal timed duration and expiration time.
- Resource bars, segmented resources and target bars also now consume the exact progress state returned by RetreatUI instead of an incomplete trigger-1 progress descriptor.
- No HUD positions, class databases, tracked spells or renderer ownership changed.

## Existing WeakAuras HUD layout

- Buffs & Procs: X 0 / Y -83.
- Secondary/custom resources: X 0 / Y -118.
- Primary resource: X 0 / Y -152, 360x16.
- Main: X 0 / Y -183, 38px icons, 1px spacing.
- Utility: X 0 / Y -224, 32px icons, 1px spacing.
- Trinkets: `ElvUF_Player`, BOTTOMRIGHT to TOPRIGHT, X -17 / Y +1.
- Target debuffs and class states remain in their established RetreatUI locations.

## Testing note

Install beta.6 over beta.5, reload UI, and run the RetreatUI installer again. Existing RetreatUI WeakAuras are updated in place. The Class WeakAuras HUD step should complete without the WeakAuras 5.21.2 `expirationTime` error.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
