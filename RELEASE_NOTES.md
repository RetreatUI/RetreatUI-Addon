# RetreatUI v1.1.7-beta.9

This prerelease fixes the remaining Necromancer resource placeholder and makes stance/form positioning a single global HUD rule instead of anchoring class states to ElvUI player-frame trinkets.

## Global stance / form lane

- Every CoA class State / stance / form WeakAura now uses one shared screen-space rule.
- The state group is no longer anchored to ElvUF_Player, so it cannot sit behind or overlap the General trinket row.
- State icons are fixed at X -188 / Y -121 and grow left from that lane.
- With 38px icons, the bottom edge is Y -140. The primary resource bar top edge is Y -144, leaving a 4px vertical gap.
- X -188 also keeps the state icon 4px clear of the widest 330px secondary-resource bar, whose left edge is X -165.
- This rule applies to every class using the shared State tracker; there are no per-class stance coordinates.

## Necromancer Life Force

- Removed the generic `Life Force` resource icon that had no spell/icon identity and therefore rendered as the red question-mark placeholder.
- Necromancer Life Force is now treated as the mirrored Ascension class resource it already was in the native HUD.
- It uses the native resource discovery path with Life Force / lifeforce keywords and aura 805011 as fallback.
- Life Force renders as segments in the secondary-resource lane at Y -118, using the original `Spell_Shadow_AnimateDead` icon source instead of a question mark.
- Reinstalling the Necromancer WeakAura HUD explicitly deletes the old beta.8 `Resource — Life Force` leaf before rebuilding the corrected package.

## Preserved HUD geometry

- Buffs & Procs: X 0 / Y -83.
- Secondary/custom resources: X 0 / Y -118.
- Primary resource: X 0 / Y -152, 360x16.
- Main: X 0 / Y -183, 38px icons, 1px spacing.
- Utility: X 0 / Y -224, 32px icons, 1px spacing.
- Trinkets remain owned by `RetreatUI - General` at the existing ElvUF_Player anchor.

The TBC-style CoA installer introduced in beta.8 remains unchanged.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
