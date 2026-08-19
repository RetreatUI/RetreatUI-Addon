# RetreatUI v1.1.7-beta.22 — Tracker Builder Test

This prerelease is an isolated Project Ascension: Conquest of Azeroth proof-of-concept for the new RetreatUI Tracker Builder.

## What this build adds

- Adds `/rui tracker`, a first 3.3.5-compatible ability/tracker browser.
- Uses RetreatUI's existing CoA class records plus the Professional Audit spell database as the catalog source.
- Adds full Professional Audit test catalogs for Barbarian, Bloodmage and Knight of Xoroth.
- Adds search plus Learned only, Recommended, Advanced and All entries filters.
- Adds Add/Remove selection for tracker definitions.
- Stores selected trackers in `RetreatUIDB` so selections can survive reloads.
- Adds a data-only tracker profile schema with validation for future RetreatUI profile import/export.
- Adds safe tracker templates for cooldowns, charges, buffs, procs, stacks, debuffs, resources and summons.

## Important safety scope

This build does **not** generate, import, replace or modify WeakAuras when using the Tracker Builder. It only browses spell data and stores tracker definitions.

The Tracker Builder does not use direct `WeakAuras.Add`, custom WeakAuras decoding, arbitrary imported Lua, runtime frame hooks or generated class WeakAura packs.

The existing beta.21 UI/install systems are otherwise left in place so this proof-of-concept can be tested independently.

## First in-game test

1. Install/update through the RetreatUI Beta channel.
2. Log into a supported CoA character, preferably Knight of Xoroth for the first pass.
3. Run `/rui tracker`.
4. Confirm the Tracker Builder opens without Lua errors.
5. Test searching by spell name and Spell ID.
6. Toggle Learned only, Recommended, Advanced and All entries.
7. Add several trackers and remove one again.
8. `/reload`, reopen `/rui tracker`, and confirm the selected count and choices persist.
9. Confirm no new WeakAuras were created or changed by these actions.

Do not promote this build to Stable until this browser/data pass is clean.

Author: Retreat
