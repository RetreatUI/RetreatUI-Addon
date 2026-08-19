# RetreatUI v1.1.7-beta.39 - Destination Routing Test

This prerelease changes Tracker Builder from a WeakAuras-only creator into a destination-aware profile editor for the native Ascension addons already shipped through the launcher.

## What changed

- Trackers now store one or more destinations: HUD (WeakAuras), Target Frame (ElvUI), and Nameplates (TurboPlates).
- Ordinary target/focus debuffs default to ElvUI + TurboPlates instead of generating a WeakAura.
- Cooldowns, buffs, procs, stacks, charges and other HUD trackers continue to use the already verified native WeakAuras import/update path.
- ElvUI 7.27 uses a dedicated `RetreatUI_SelectedDebuffs` Whitelist. The target debuff row stays disabled when nothing is selected and shows only selected entries when enabled.
- TurboPlates 1.4.5 uses its native aura Spell-ID whitelist for selected Nameplates debuffs.
- Legacy RetreatUI auto-whitelisted class debuffs are guarded so they cannot bypass the new explicit destination selection.
- Tracker profile schema is now 3 and persists destination choices. Schema 1 and 2 imports remain accepted and are migrated.
- A tracker without HUD selected cannot build a WeakAura.
- Existing managed WeakAura identity/update behavior is unchanged.

## Focused live test

1. Open `/rui tracker` and edit Bite Wound.
2. Use Debuff + Unit: Target.
3. Leave HUD unchecked and enable Target Frame + Nameplates.
4. Save the tracker. No WeakAura should be created or required.
5. Apply Bite Wound to a target. It should appear on the ElvUI target frame and on the TurboPlates nameplate.
6. Edit Apotheosis or Rotclaw and confirm HUD remains selected and `Build WeakAura` still opens the normal managed WeakAuras import/update flow.
7. Confirm no Lua errors.

## Safety rules

- No custom aura runtime engine.
- No custom WeakAuras trigger Lua.
- No `WeakAuras.Add`.
- No custom WeakAuras decoder.
- No automatic WeakAuras import/update acceptance.
- Stable/main remains untouched.

Author: Retreat
