# RetreatUI v1.1.2-beta.29

Emergency hotfix for Ascension's native Character Advancement assertion:

`CharacterAdvancementBuildEntry::UpdatePointers: entry ... not found`

This failure is raised by Ascension.exe itself and cannot be caught by Lua `pcall`. It can occur when the active Character Advancement build contains a stale or removed entry and an addon queries Character Advancement or `IsSpellKnown` while the build pointers are being refreshed.

## Fix

- RetreatUI no longer queries `C_CharacterAdvancement` from the live HUD path.
- Collector entry IDs remain in the class databases as audit metadata, but are not queried at runtime.
- Learned spell detection now uses the player's live spellbook and does not call `IsSpellKnown` as a fallback.
- All beta.28 class changes, HUD whitelists and Eternal Bloodmage behavior remain included.
- Party utility and party interrupt tracking remain removed.
