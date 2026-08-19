# RetreatUI v1.1.7-beta.27 - Tracker HUD Layout Polish

This prerelease fixes the first beta.26 in-game Tracker HUD Layout pass.

## What changed from beta.26

- Replaces the cramped vertical default stack with six clearly separated default group positions around the screen center.
- Migrates only untouched beta.26 default positions to the new layout; groups the user already moved or customized are preserved.
- Bumps the tracker group layout schema to 2.
- Makes Tracker HUD Layout behave like a proper edit mode: opening it hides Tracker Builder, and Done returns to Tracker Builder.
- Keeps Main, Procs / Buffs, Defensives, Utility, Resources and Target independently movable.
- Keeps per-group Scale, Spacing, Growth and Reset.
- Keeps class-specific persistence and validated profile layout data.

## Safety scope

This remains a data/layout preview only. No WeakAuras are generated, imported, replaced or modified, and no live combat tracker renderer is connected yet.

## What to test

1. Open `/rui tracker` and click `HUD Layout`.
2. Confirm Tracker Builder hides while edit mode is active.
3. Confirm all six group handles start clearly separated with no overlapping labels.
4. Drag a group, change Scale, Spacing and Growth, then press Done.
5. Reopen HUD Layout and confirm the changes persist.
6. `/reload`, reopen it again and confirm persistence.
7. Reset one group and confirm only that group returns to its new default position/settings.
8. Confirm Done returns to Tracker Builder.
9. Confirm no WeakAuras were created or changed.

Do not promote this build to Stable.

Author: Retreat
