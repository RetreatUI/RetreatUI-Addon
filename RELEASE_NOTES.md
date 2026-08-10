# RetreatUI v1.1.7-beta.7

This prerelease restructures the CoA WeakAuras HUD to match the proven RetreatUI TBC model and restores the exact class curation used by the previous native HUD.

## TBC-style WeakAura profiles

- The shared `RetreatUI - General` package remains responsible for Trinkets and Buffs & Procs.
- The active CoA class now exposes separate top-level Resource, Main, Utility, State and Target WeakAura groups instead of one large outer class wrapper.
- Main and Utility now contain one WeakAura per ability, matching the TBC profile structure. The previous cloned `— Abilities` catch-all displays are removed during upgrade.
- Old RetreatUI class WeakAura packages for other CoA classes are removed when the current class package is installed, so Bloodmage/Guardian/other stale class roots no longer remain loaded on every class.

## Exact native-HUD curation

- AdvancedHUD's existing per-class `coreOrder`, `utilityOrder`, strict-order flags and row limits are captured and reused by WeakAuras. This keeps the same spells, order and limits that were already curated before the renderer migration.
- Runtime form/combat/custom visibility gates are preserved, including Bloodmage form-specific abilities.
- CoA Buffs & Procs returns to the native HUD rule: only explicit `auraTracker=true` class records are shown. The broad temporary-buff fallback introduced during the first WA migration is removed.

## Class state cleanup

- State WeakAuras now reuse the existing grouped StateTracker collector: one active state per class-state group, with active shapeshift state taking priority over the matching aura.
- This removes duplicate stance/form displays caused by independently adding both an aura state and a shapeshift state.
- Bloodmage keeps the intended Mortal/Cursed fallback behavior.

## Existing HUD geometry is unchanged

- Buffs & Procs: X 0 / Y -83.
- Secondary/custom resources: X 0 / Y -118.
- Primary resource: X 0 / Y -152, 360x16.
- Main: X 0 / Y -183, 38px icons, 1px spacing.
- Utility: X 0 / Y -224, 32px icons, 1px spacing.
- Trinkets: `ElvUF_Player`, BOTTOMRIGHT to TOPRIGHT, X -17 / Y +1.
- Target debuffs and class states remain in their established RetreatUI locations.

The WeakAuras 5.21.2 compatibility fixes from beta.5 and beta.6 remain active.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
