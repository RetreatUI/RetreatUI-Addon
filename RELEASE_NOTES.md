# RetreatUI v1.1.7-beta.1

This prerelease focuses on fixing ElvUI chat tabs overlapping after users create additional chat windows/tabs.

## Chat and ElvUI

- Stops RetreatUI from managing ElvUI/Blizzard chat docking.
- Prevents the old Loot/Trade cleanup from undocking or closing newly-created chat frames before ElvUI finishes attaching them.
- Leaves chat tab creation, docking, positioning and closing entirely to ElvUI/Blizzard while preserving RetreatUI chat styling.
- Keeps the existing right-chat panel and user-created tabs untouched.

## Testing note

Users whose chat tabs were already left undocked or overlapping may need to re-dock or reset the affected tab once after updating. RetreatUI will no longer mutate chat docking afterward.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
