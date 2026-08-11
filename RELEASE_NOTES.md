# RetreatUI v1.1.7-beta.15

This prerelease makes the Conquest of Azeroth stance/state lane deterministic for every class and every spec.

## Final CoA stance lane

- One global placement rule now applies to all stance, form, aspect, oath, formation, presence and other class-state icons.
- The two 30x30 trinkets define an exact 63x30 anchor lane above the player/resource area.
- Every 38x38 class-state icon starts exactly 6px to the right of that trinket lane.
- State icons are bottom-aligned with the trinkets, so their extra 8px of height grows upward and cannot extend down into the primary resource bar.
- No class or spec is allowed to apply a separate stance X/Y offset.
- The final validator supersedes the retired beta.10 screen-centre validation that caused Bloodmage to fail with `Class State WeakAura is not on the global center lane`.
- Existing beta.9-beta.12 migration layers remain for upgrade compatibility, but beta.15 is the final authority for state geometry and validation.

## Packaging

The release ZIP contains the three independent WoW addon roots:

- `RetreatUI`
- `RetreatUI_Classes`
- `RetreatUI_BuffManager`

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
