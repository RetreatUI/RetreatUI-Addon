RETREATUI CLASSES v1.0.11-beta.12
==========================

This addon is bundled with RetreatUI and must always use the same version as Core.

CLASS COVERAGE
- All 21 Conquest of Azeroth classes are supported.
- Learned-only spellbook data is used across every collected specialization.
- Main Rotation contains learned core abilities and relevant offensive cooldowns.
- Utility contains interrupts, taunts, control, movement, defensives and racials.
- Proc tracking is active-only and deduplicated by live aura ID or name.
- Target debuff bars show player, pet and vehicle-applied effects; casterless Ascension class auras are matched against the active class database.

CLASS-STATE TRACKER
- Curated state families include stances, forms, vows, aspects, oaths, formations, inscriptions, modes, augmentations and similar class systems.
- Every family can show only one active member at a time.
- Detection uses exact names, verified IDs, aliases and narrowly scoped class prefixes.
- Server modes, unrelated buffs and ordinary combat procs cannot appear in the state row.
- Bloodmage form detection is internal only and does not create a visible Mortal/Cursed tracker.
- Sun Cleric Vows and Templar Oaths update automatically when their active aura changes.

CUSTOM CLASS SYSTEMS
- Knight of Xoroth: Demonfire, Demon's Blood, Hellfire Imp, Pestilence and target-debuff handling.
- Bloodmage: form-dependent spell eligibility, Eternal Resolve and class-specific trackers.
- Felsworn: dedicated Felfury, Chaos Rush and Inner Demon tracking.
- Necromancer: Life Force systems and a Guardian HUD with individual minion health bars, Zombie tracking and a movable L/U lock control.

The class database contains thousands of collected tree entries and resolved spell records. Hidden runtime aura IDs and build-specific priorities can still require player feedback after Ascension changes.

Shared layout, theme, counter, cooldown and migration behavior is provided by RetreatUI Core.
