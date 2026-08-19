# RetreatUI v1.1.7-beta.26 - Tracker HUD Layout Test

This prerelease builds on the successful beta.25 Tracker Editor/grouping test.

## What changed from beta.25

- Adds a dedicated data-driven Tracker HUD Layout editor.
- Adds a `HUD Layout` button directly in the Tracker Builder.
- Shows movable handles for Main, Procs / Buffs, Defensives, Utility, Resources and Target groups.
- Group handles show the number of selected trackers assigned to that group.
- Group positions can be moved by drag and drop.
- Adds per-group Scale controls from 50% to 200%.
- Adds per-group Spacing controls from 0 to 24 px.
- Adds per-group growth direction: Right, Left, Up and Down.
- Adds per-group Reset.
- Stores group layout independently per CoA class.
- Includes tracker group layout data in the validated Tracker profile schema for future unified RetreatUI profile import/export.
- Keeps beta.25 Tracker Editor behavior and saved user choices intact.

## Important safety scope

The Tracker HUD Layout editor is still a preview/data editor only. It does not create, import, replace or modify WeakAuras and does not render live combat trackers yet.

No custom WeakAuras decoding, direct WeakAuras.Add calls, arbitrary imported Lua or runtime tracker renderer is added in this build.

## What to test

1. Open `/rui tracker` and confirm the existing Tracker Builder still loads correctly.
2. Confirm your beta.25 selected trackers and groups are still present.
3. Click `HUD Layout` at the bottom-right of the Tracker Builder.
4. Confirm all six group handles appear without Lua errors.
5. Drag one or more group handles and close/reopen the editor.
6. Select a handle and change Scale, Spacing and Growth.
7. Use Reset on one group and confirm only that group returns to its default position/settings.
8. `/reload`, reopen the HUD Layout editor, and confirm positions, scale, spacing and growth persist.
9. Confirm the group count matches the trackers assigned in the Tracker Editor.
10. Confirm no WeakAuras were created or changed.

Do not promote this build to Stable. If this data/layout pass is clean, the next stage is connecting these group definitions to a safe tracker rendering backend.

Author: Retreat
