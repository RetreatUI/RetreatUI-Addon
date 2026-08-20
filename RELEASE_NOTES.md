# RetreatUI v1.1.7-beta.48 - Real Profile Switching

This prerelease fixes the two beta.47 regressions reported during live testing: profile selection did not visibly switch ElvUI layouts, and the RetreatUI workspace still felt incorrectly scaled.

## Real ElvUI profile switching

- Retreat Focus now installs and activates as its own ElvUI profile: `Retreat Focus`.
- Retreat Edge now installs and activates as its own ElvUI profile: `Retreat Edge`.
- The two choices no longer overwrite the same `RetreatUI` ElvUI profile.
- The ACTIVE state is derived from the ElvUI profile that is actually active, not merely the last RetreatUI card clicked.
- If Ascension ElvUI can decode the bundled reference profile, that decoded profile is used.
- If the reference payload cannot be decoded, RetreatUI creates two visibly different CoA-compatible profile conversions instead of falling back to the same layout.

## UI scale safety

- beta.47's non-1 workspace scale layer is no longer loaded.
- RetreatUI runs at native frame scale (`1.0`).
- Profile switching snapshots and restores the existing WoW `useUiScale` and `uiScale` CVars.
- Imported ElvUI profile data has profile-level autoscale/custom-scale fields removed before activation.
- RetreatUI does not intentionally change the user's global WoW or ElvUI UI scale.

## Workspace readability

- The large integrated workspace remains available and resizable.
- Default workspace dimensions are kept within the current UI canvas rather than using an extra zoom factor.
- Small labels are promoted to readable native font sizes without scaling the entire frame.
- The current page is reflowed immediately after the native workspace size is applied.

## HUD retained

- Search by spell name or Spell ID.
- Choose Main Ability, Buff / Proc, Utility, Defensive or Target Debuff.
- Drag spells into exact action-bar style slots.
- User-created bars with custom slot count and Horizontal / Vertical orientation.
- Empty slots remain empty.
- Existing HUD icons can be reordered between slots.
- Source/cooldown IDs remain separate from applied aura/effect IDs.

## Safety

- Professional Audit remains the canonical CoA spell/effect source.
- No custom WeakAuras trigger Lua.
- No direct WeakAuras insertion API.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
