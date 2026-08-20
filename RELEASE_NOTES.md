# RetreatUI v1.1.7-beta.45 - Profile Shell

This prerelease replaces the old step-by-step profile/tracker workflow with the new RetreatUI profile shell.

## New profile flow

- Choose between two RetreatUI-owned UI styles: **Retreat Focus** and **Retreat Edge**.
- One profile action configures ElvUI, TurboPlates and Details together.
- 1080p / 1440p source payloads are selected automatically from the current screen height.
- Imported profile payloads are integrity-checked before use. If Ascension's ElvUI fork cannot decode a payload, RetreatUI falls back to the verified CoA-compatible profile instead of leaving a partial installation.
- ElvUI private profile data uses the native private-profile storage path; Details uses its native profile importer.

## HUD and WeakAuras

- WeakAuras are no longer part of the full UI profile installation.
- The HUD page is the user-facing path for creating native WeakAura elements from the CoA spell database and Professional Audit.
- Source/cooldown IDs and applied aura/effect IDs remain separated behind the scenes.
- The existing HUD mover is exposed as **Unlock Mode** for positioning and scaling.

## Profile ownership

- ElvUI and TurboPlates are profile-owned in beta.45.
- The old per-spell Target Frame / Nameplates destination routing no longer writes into those addons.
- Existing beta.42-beta.44 TurboPlates destination state is retired and previously managed user values are restored where possible.
- CoA-specific TurboPlates compatibility, NPC cast handling and runtime safety remain available independently of tracker destinations.

## Interface

- New page-based RetreatUI shell with Home, Profiles, HUD, Unit Frames, Nameplates, Damage Meter and Settings pages.
- Profile installation, component repair, reload and Unlock Mode are available from one window.
- Installed UI/profile names are RetreatUI-owned.

## Safety

- Professional Audit remains the source of CoA spell/effect identity for the HUD builder.
- No custom aura runtime engine.
- No custom WeakAuras trigger Lua.
- No direct WeakAuras insertion API.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
