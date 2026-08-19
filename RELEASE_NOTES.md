# RetreatUI v1.1.7-beta.41 - Authoritative Tracker Destinations

This prerelease combines the beta.40 ElvUI target-debuff filter fix with authoritative TurboPlates destination control.

## What changed

- Keeps destination-aware routing: HUD (WeakAuras), Target Frame (ElvUI), Nameplates (TurboPlates).
- Keeps the beta.40 ElvUI target-debuff filter compatibility fix.
- Makes selected debuff tracker destinations authoritative in TurboPlates.
- Nameplates ON removes any TurboPlates blacklist entry and whitelists the selected debuff.
- Nameplates OFF removes any whitelist entry and actively blacklists the selected debuff so an older TurboPlates profile cannot keep showing it.
- Removing the tracker entirely restores the TurboPlates whitelist/blacklist state that existed before RetreatUI took ownership.
- WeakAuras behavior is unchanged.

## Focused live test

1. Keep Bite Wound selected as a Debuff on Unit: Target.
2. Enable Target Frame (ElvUI), disable HUD and disable Nameplates (TurboPlates).
3. Save and apply Bite Wound. It must NOT appear on TurboPlates.
4. Confirm Bite Wound appears on the ElvUI target frame.
5. Re-enable Nameplates, save, and apply Bite Wound again. It must return to TurboPlates.
6. Confirm no Bite Wound WeakAura is created and no Lua errors occur.

## Safety rules

- No custom aura runtime engine.
- No custom WeakAuras trigger Lua.
- No `WeakAuras.Add`.
- No custom WeakAuras decoder.
- Stable/main remains untouched.

Author: Retreat
