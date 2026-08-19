# RetreatUI v1.1.7-beta.24 - Tracker Editor Test

This prerelease builds on the successful beta.23 Tracker Builder data/browser pass.

## What changed from beta.23

- Add now opens a dedicated Tracker Editor instead of immediately storing only the first inferred tracking type.
- Existing selected trackers open as Edit and can be changed or removed from the editor.
- Trackers can combine multiple tracking types: Cooldown, Buff, Proc, Debuff, Stacks, Charges, Resource and Summon/Pet.
- Suggested tracking types are preselected from the spell metadata, but the user can change them.
- Adds data-only settings for Unit, Icon/Bar display, icon size, glow, cooldown text, duration, stacks/charges, learned-only and combat-only.
- Multi-type tracker definitions and settings are validated before future profile import/export.
- Tightens Recommended so it is intended as a small high-signal learned-spell list rather than a broad class-wide list.
- Recommended now automatically enables Learned only.
- Folds the beta.23 footer-height hotfix directly into TrackerBuilder and removes the temporary wrapper file.

## Important safety scope

The Tracker Editor still does not generate, import, replace or modify WeakAuras. It only stores validated tracker definitions in RetreatUIDB.

No custom WeakAuras decoding, direct WeakAuras.Add calls, arbitrary imported Lua or runtime tracker rendering is added in this build.

## What to test

1. Open `/rui tracker` and confirm the browser still loads cleanly.
2. Enable Recommended and confirm Learned only is enabled automatically and the result count is substantially smaller than beta.23.
3. Click Add on Apotheosis and confirm Cooldown + Buff are preselected.
4. Change one or more options, then Add Tracker.
5. Confirm the row changes from Add to Edit and displays the saved tracking types.
6. Reopen Edit and confirm the saved settings are restored.
7. Test a multi-type ability such as Blood Tap and save Cooldown + Resource.
8. Remove one tracker from inside the editor.
9. `/reload`, reopen `/rui tracker`, and confirm the saved tracker types/settings still persist.
10. Confirm no WeakAuras were created or changed.

Do not promote this build to Stable. This is still a data/editor proof-of-concept.

Author: Retreat
