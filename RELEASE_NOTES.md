# RetreatUI v1.1.7-beta.50 - Unified Installer and HUD Unlock

This prerelease cleans up the installer architecture after beta.49 live testing exposed overlapping legacy systems and an unstable HUD unlock flow.

## One installer only

- RetreatUI now exposes one main workspace only.
- Visible navigation is reduced to Home, Profiles, HUD and Settings.
- ElvUI, TurboPlates and Details remain components of the selected UI profile rather than separate installer wizards.
- The legacy beta.20 installer is removed from the runtime load path.
- The legacy beta.20 WeakAura installer bridge is removed from the runtime load path.
- Installing Retreat Focus or Retreat Edge marks the new profile-shell installation as complete.

## HUD architecture

- The old RetreatUI HUD Editor is removed from the runtime load path.
- The old separate Tracker Builder is no longer reachable as a separate user workflow.
- `/rui hud`, `/rui tracker`, `/rui builder` and `/rui editor` all open the integrated HUD page.
- No prebuilt class WeakAura package is installed.
- The legacy native class-HUD installer state is retired for beta.50.

## New HUD Unlock Mode

- Unlock Mode now operates only on the user-created HUD bars from the integrated HUD page.
- Every HUD bar appears as a draggable action-bar-style mover with its real slot count, icon size and orientation.
- Bar positions save directly to the same `x` / `y` values consumed by the WeakAuras group builder.
- Main Rotation, Utility and custom bars can all be positioned independently.
- No legacy HUD mover database is involved.
- ElvUI unit frames remain owned by ElvUI and are not moved by HUD Unlock Mode.

## Reference profile runtime

- beta.50 attempts to decode the original supplied ElvUI profile transmission before using the native CoA fallback.
- Retreat Focus uses the supplied 1440p/1080p reference transmission when Ascension ElvUI accepts it.
- The known-broken Edge 1440 Lua wrapper from beta.48 is not loaded.
- Until that wrapper is regenerated safely from the source ZIP, Edge uses the valid supplied Edge 1080 transmission on both test resolutions.
- If Ascension ElvUI rejects a reference transmission, the native CoA profile remains the fallback.
- WoW `uiScale` and `useUiScale` are preserved during profile activation.

## WeakAuras HUD builder

- Search by spell name or exact Spell ID.
- Choose Main Ability, Buff / Proc, Utility, Defensive or Target Debuff.
- Drag a spell directly into a fixed slot.
- Create multiple bars with custom slot counts.
- Choose Horizontal or Vertical orientation per bar.
- Empty slots remain empty and preserve their exact positions.
- No custom WeakAuras trigger Lua.
- No direct WeakAuras insertion API.

## Safety

- Professional Audit remains the canonical CoA spell/effect identity source.
- The previous compressed Details transmissions remain disabled on CoA to avoid decode/decompress errors.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
