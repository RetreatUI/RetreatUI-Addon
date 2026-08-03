# RetreatUI v1.1.2-beta.30

Performance and release-candidate test build based on the stable beta.29 crash fix.

## Performance changes

- Centralized spell, talent and build refresh scheduling instead of running separate four-pass refresh loops in Core Events and BuildProfiles.
- Added a short shared spellbook-scan cache so overlapping RetreatUI systems reuse the same live spellbook result.
- Reduced a normal event burst from many repeated spellbook scans and HUD rebuilds to one debounced primary refresh and, where needed, one delayed settlement check.
- Expensive build/profile reconstruction is deferred until combat ends if Ascension dispatches spellbook or talent events during a pull.
- NPC cooldown tracking now caches active nameplates by GUID rather than enumerating every nameplate for every mob spell cast.
- NPC cooldown icons cache their texture and no longer re-sort unchanged entries every update tick.
- NPC cooldown text updates every 0.15 seconds instead of every 0.10 seconds.

## Retained safety and class changes

- Keeps beta.29's protection against the native `CharacterAdvancementBuildEntry::UpdatePointers` crash.
- Keeps all curated beta.28 Pyromancer, Tinker, non-Eternal Bloodmage, Templar and Chronomancer data.
- Eternal Bloodmage remains isolated from non-Eternal audit records.
- Audit records cannot automatically expand approved HUD rows.
- Party utility and party interrupt tracking remain removed.

This build is intended for dungeon and raid testing before `1.1.2-rc.1`.
