# RetreatUI v1.1.7-beta.2

This prerelease focuses on the CoA chat-tab overlap reported by users with additional ElvUI chat tabs.

## Chat and ElvUI

- Removes RetreatUI's remaining runtime management of Loot/Trade chat windows.
- Removes the old chat-docking safety module entirely.
- Stops RetreatUI from docking, undocking, closing, hiding or repositioning chat frames after login.
- Leaves chat tab creation, docking, positioning and closing entirely to ElvUI/Blizzard while preserving the RetreatUI ElvUI profile and chat styling.

## Testing note

If a chat tab is already undocked or overlapping from an older build, re-dock or reset that affected tab once after updating. RetreatUI will no longer mutate chat docking afterward.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
