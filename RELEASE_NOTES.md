# RetreatUI v1.1.7-beta.40 - ElvUI Target Debuff Filter Fix

This prerelease is a focused follow-up to beta.39 destination routing.

## What changed

- Keeps the beta.39 destination model unchanged: HUD (WeakAuras), Target Frame (ElvUI), Nameplates (TurboPlates).
- Fixes ElvUI target-debuff routing for the Ascension/WotLK ElvUI 7.27 filter structure.
- Writes the selected-only whitelist priority to both the legacy direct fields and the WotLK/Classic nested `debuffs.filters` fields.
- Keeps the dedicated `RetreatUI_SelectedDebuffs` Whitelist and HARMFUL aura filter.
- TurboPlates routing is unchanged and already live-verified with Bite Wound.
- WeakAuras cooldown/buff/charge generation is unchanged.

## Focused live test

1. Keep Bite Wound routed to Target Frame + Nameplates with HUD disabled.
2. Save the tracker and apply Bite Wound to the target.
3. Confirm Bite Wound appears on the ElvUI target frame and TurboPlates nameplate.
4. Confirm no Bite Wound WeakAura is created.
5. Confirm no Lua errors.

## Safety rules

- No custom aura runtime engine.
- No custom WeakAuras trigger Lua.
- No `WeakAuras.Add`.
- No custom WeakAuras decoder.
- Stable/main remains untouched.

Author: Retreat
