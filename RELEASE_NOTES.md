# RetreatUI v1.1.7-beta.25 - Tracker Editor Polish Test

This prerelease builds on the successful beta.24 Tracker Editor test.

## What changed from beta.24

- Keeps user-selected multi-type combinations exactly as saved.
- Confirms curated Apotheosis defaults remain Cooldown + Buff; extra types such as Resource are only retained when the user explicitly selected them.
- Adds a HUD Group field to every tracker definition.
- Available groups: Main, Procs / Buffs, Defensives, Utility, Resources and Target.
- New trackers receive a deterministic suggested group based on their curated category/tracking type, but the user can change the group freely.
- Existing tracker group choices persist with the rest of the tracker profile data.
- Gives the Tracker Builder metadata line more horizontal room so long multi-type selections no longer wrap into adjacent rows.
- Keeps Recommended tied to Learned only.

## Important safety scope

The Tracker Editor still does not generate, import, replace or modify WeakAuras. It only stores tracker/profile/layout intent as data in RetreatUIDB.

No custom WeakAuras decoding, direct WeakAuras.Add calls, arbitrary imported Lua or runtime tracker renderer is added in this build.

## What to test

1. Open `/rui tracker` and confirm the browser still loads cleanly.
2. Open Apotheosis as a fresh/new tracker and confirm the suggested types are Cooldown + Buff.
3. Add an extra type manually if desired and confirm it is preserved after reopening the editor.
4. Change Group and confirm the selected group is restored after reopening.
5. Confirm long multi-type rows stay on one metadata line in the Builder.
6. `/reload`, reopen `/rui tracker`, and confirm tracker types, group, size, glow and conditions persist.
7. Confirm no WeakAuras were created or changed.

Do not promote this build to Stable. The next stage is the data-driven HUD layout/group editor before any WeakAura renderer is connected.

Author: Retreat
