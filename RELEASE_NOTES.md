# RetreatUI v1.1.2-beta.28

This release restores the verified class research from beta.26 without restoring the broad HUD expansion that caused unrelated abilities to appear.

## Class updates

- **Pyromancer:** Restored healer runtime IDs, active effects and Flameweaving support. Newly audited actions remain data-only unless explicitly approved, and the previous core, utility and proc row limits are unchanged.
- **Tinker:** Restored Overcharge and Discombobulate as the only newly approved HUD actions, together with Eureka, Nanobot effects and the compact personal-pet action/mana tracker. The class remains locked to its curated 7-core and 8-utility profile.
- **Bloodmage:** Restored verified Fleshweaver, Sanguine and Accursed runtime/aura data. Eternal Bloodmage remains isolated and unchanged; newly audited non-Eternal actions are not automatically added to HUD rows.
- **Templar:** Restored runtime variants, Oath Chain resource coverage, Divine Stand and Holy Stagger. Oaths remain state tracking and are never treated as Main Rotation abilities.
- **Chronomancer:** Restored runtime variants, Endless Sands and Aeon/Sands resource coverage. Hasten and Time Out remain data-only pending explicit HUD approval.

## Safety changes

- Multiple replacement cooldown and charge IDs are supported again, but runtime IDs can no longer count as proof that an ability is learned.
- A shared audit guard blocks unapproved audit records from forcing themselves into core, utility, target-debuff or party-cooldown displays.
- Tinker's live spellbook safety net is disabled for its locked profile, preventing newly discovered class cooldowns from bypassing the whitelist.
- Missing Tinker pet textures are hidden instead of showing question-mark placeholders.
- Party utility and party interrupt tracking remain removed.
