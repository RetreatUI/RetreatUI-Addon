# RetreatUI v1.1.2

RetreatUI 1.1.2 promotes the current beta.30 codebase to the stable Release channel.

## Removed systems

Party utility and interrupt tracking have been permanently removed. This includes party interrupts, combat resurrection tracking, dispels, externals and group defensives. The component no longer appears in the modular installer, and an upgrade migration disables old SavedVariables so previous profiles cannot re-enable it.

## Performance and stability

- Centralized spell, talent and build refresh scheduling instead of overlapping multi-pass refresh loops.
- Added a short shared spellbook-scan cache so RetreatUI systems reuse the same live spellbook result.
- Defers expensive build/profile and HUD reconstruction until combat ends when Ascension dispatches relevant events during a pull.
- NPC cooldown tracking caches active nameplates by GUID and caches spell textures.
- Keeps protection against the native `CharacterAdvancementBuildEntry::UpdatePointers` crash.

## Class and HUD changes

- Includes the curated Pyromancer, Tinker, non-Eternal Bloodmage, Templar and Chronomancer class updates developed through beta.28-beta.30.
- Eternal Bloodmage remains isolated from non-Eternal Bloodmage audit records.
- Runtime replacement IDs can read cooldowns without making an unlearned ability appear on the HUD.
- Audit records cannot automatically expand approved HUD rows.
- Tinker remains locked to its curated HUD rows.

This is the stable successor to RetreatUI 1.1.0 and replaces the beta.30 prerelease for Release-channel users.
