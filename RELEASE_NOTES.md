# RetreatUI v1.1.7-beta.14

This prerelease fixes the Conquest of Azeroth class state / stance placement so stance, form, aspect, oath, formation and presence trackers use the trinket row as their single authoritative anchor.

## CoA stance placement

- Class state icons now sit directly to the right of the RetreatUI trinket tracker.
- State icons use the exact same vertical lane as the trinkets, immediately above the primary resource bar.
- Removed the Guardian-specific vertical state offset so Guardian follows the same placement rule as every other CoA class.
- Removed the old absolute-position behavior as the final authority after HUD refreshes.
- State placement is reflowed synchronously after state updates and trinket refreshes, preventing icons from jumping back to stale class-specific coordinates.
- Legacy form trackers and the shared class-state tracker both use the same global placement rule.

## Packaging

The release ZIP contains the three independent WoW addon roots:

- `RetreatUI`
- `RetreatUI_Classes`
- `RetreatUI_BuffManager`

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
