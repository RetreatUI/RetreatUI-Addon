# RetreatUI v1.1.7-beta.10

This prerelease corrects the global CoA stance/form lane after live testing and moves normal race abilities out of class Utility packages into RetreatUI - General.

## Global stance / form placement

- beta.9 placed the State group at X -188 / Y -121. The Y coordinate was correct, but X -188 put the group outside the 360px center HUD gap and back into the player-frame area.
- Every CoA State / stance / form group now uses one fixed screen-space rule: X 0 / Y -121.
- The group is CENTER anchored and centered horizontally, so one or several active states remain directly above the primary resource bar instead of growing into either unit frame.
- State icons remain 38px. Their bottom edge is Y -140 while the primary resource bar top edge is Y -144, preserving a 4px vertical gap.
- This is one global rule for Bloodmage forms, Guardian formations, Necromancer forms, Knight of Xoroth states and every other class using the shared State tracker.

## Racials belong to General

- Normal race-specific active abilities are no longer owned by each class Utility WeakAura group.
- RetreatUI - General now contains a dedicated `Racials` subgroup.
- The racial group uses the existing race spellbook scanner and tracks cooldowns, charges and active racial buff durations.
- Racials are positioned beside the General trinket row rather than consuming a class Utility slot.
- Reinstalling the WeakAura HUD clears stale General racial children before rebuilding the current character's racial tracker.

## Existing HUD geometry

- Buffs & Procs: X 0 / Y -83.
- Secondary/custom resources: X 0 / Y -118.
- Primary resource: X 0 / Y -152, 360x16.
- State / stance / form: X 0 / Y -121, 38px icons, centered.
- Main: X 0 / Y -183, 38px icons, 1px spacing.
- Utility: X 0 / Y -224, 32px icons, 1px spacing.
- Trinkets remain owned by `RetreatUI - General` at the existing ElvUF_Player anchor.

Necromancer Life Force remains on the corrected mirrored-resource path introduced in beta.9, and the TBC-style CoA installer remains unchanged.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
