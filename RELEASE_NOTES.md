# RetreatUI v1.1.7-beta.16

This prerelease removes the guessed CoA stance geometry, restores the clean target frame, and puts Knight of Xoroth back on an explicitly curated HUD.

## Stance / state placement

- Stance, form, aspect, oath, formation, presence and Pestilence trackers now anchor to the **actual rendered right edge** of the trinket tracker.
- The old theoretical `63px` trinket width is gone; no icon-count calculation is used to decide where stance begins.
- Both native RetreatUI state trackers and WeakAuras state groups use the same rendered trinket edge.
- State icons begin 6px after that edge and are bottom-aligned with the trinkets, so 38x38 state icons grow upward rather than into the resource bar.
- If the real trinket region is not available yet, state trackers stay off-screen until it exists instead of falling back to guessed screen coordinates.

## Knight of Xoroth cleanup

- Retires the old bespoke KoX Pestilence tracker as a visible tracker.
- Pestilence is now owned by the same global class-state tracker used by the other CoA classes.
- KoX live-spellbook cooldown discovery no longer repopulates the HUD with every discovered cooldown.
- The visible KoX action rows are deliberately small:
  - Core: `Unleash Pestilence`
  - Utility: `Chainwhip`, `Snarl`
- Active aura trackers are limited to `Suffuse`, `Hellrider`, and `Black Shield`.
- Demonfire, Hellfire Imp, Demon's Blood and the existing resource/counter logic remain intact.

## Target frame cleanup

- The generic ElvUI target-frame debuff row is disabled again.
- The old KoX target-frame debuff bars are suppressed.
- Target debuffs are no longer allowed to turn the target frame into a generic aura dump; any future target mechanic display must be individually curated.

## Packaging

The release ZIP contains the three independent WoW addon roots:

- `RetreatUI`
- `RetreatUI_Classes`
- `RetreatUI_BuffManager`

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
