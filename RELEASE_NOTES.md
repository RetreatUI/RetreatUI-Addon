# RetreatUI v1.1.7-beta.51 - Installer Redesign

This prerelease replaces the beta.50 presentation layer and removes silent ElvUI compatibility fallbacks.

## Installer visual rewrite

- New RetreatUI shell built from scratch rather than patching the beta.50 cards.
- Denser Ellesmere-style options layout with a fixed top bar, compact sidebar and structured content surfaces.
- Removed the permanent green/debug footer status line.
- Status feedback now appears as a temporary toast.
- Profile cards include a compact visual layout preview and clearer active state.
- Profile components are shown as compact pills rather than large empty sections.
- Workspace size is reduced to a focused editor footprint while keeping the HUD workspace large enough for three-pane editing.
- Home, Profiles, HUD and Settings remain the only visible top-level pages.

## Exact ElvUI profile policy

- Retreat Focus and Retreat Edge now require the original supplied ElvUI profile payloads.
- RetreatUI no longer silently substitutes a native CoA fallback when an original profile cannot be decoded.
- The decoded source profile table is stored without RetreatUI mover/layout rewrites.
- Only the conflicting ElvUI nameplate module is disabled after activation because TurboPlates owns nameplates.
- WoW global `uiScale` and `useUiScale` are restored after activation.
- If Ascension's ElvUI rejects an original payload, the installer reports the failure instead of pretending that the profile installed successfully.

## HUD

- The integrated slot-based HUD remains unchanged from beta.50.
- Search by spell name or exact Spell ID.
- Choose Main Ability, Buff / Proc, Utility, Defensive or Target Debuff.
- Drag spells into fixed action-bar-style slots.
- Create multiple horizontal or vertical bars.
- Unlock Mode moves only user-created HUD bars.
- No legacy RetreatUI HUD Editor is loaded.
- No separate Tracker Builder user workflow is exposed.

## Safety

- No global UI-scale manipulation by RetreatUI.
- No custom WeakAuras trigger Lua.
- No direct WeakAuras insertion API.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
