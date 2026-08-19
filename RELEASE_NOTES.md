# RetreatUI v1.1.7-beta.23 — Tracker Builder Layout Test

This prerelease is a small follow-up to beta.22 for the new RetreatUI Tracker Builder proof-of-concept.

## What changed from beta.22

- Fixes the bottom-row overlap visible in the first in-game Bloodmage test.
- Keeps all 12 spell rows per page, but increases the Tracker Builder frame height so the final row no longer collides with Previous / Next / Page controls.
- Keeps the exact same tracker catalog, filters, Add/Remove storage and safety scope as beta.22.

## Tracker Builder test scope

- `/rui tracker`
- Search by spell name / Spell ID / category
- Learned only
- Recommended
- Advanced
- All entries
- Add / Remove tracker definitions
- Selected trackers persist in `RetreatUIDB`
- Professional Audit test catalogs for Barbarian, Bloodmage, Chronomancer and Knight of Xoroth

## Important safety scope

The Tracker Builder still does **not** generate, import, replace or modify WeakAuras. This build only browses spell data and stores tracker definitions.

## What to test

1. Open `/rui tracker` and confirm the footer no longer overlaps the final ability row.
2. Search by spell name and by Spell ID.
3. Toggle Learned only, Recommended, Advanced and All entries.
4. Add several trackers and remove one.
5. `/reload`, reopen `/rui tracker`, and confirm the selected trackers persist.
6. Confirm no WeakAuras were created or changed.

Do not promote this build to Stable until the Tracker Builder data/browser pass is clean.

Author: Retreat
