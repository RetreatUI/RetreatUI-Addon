# RetreatUI v1.1.7-beta.42 - Bite Wound Aura Identity Fix

This prerelease keeps the beta.41 destination-routing logic unchanged and fixes the actual applied aura identity used by ElvUI and TurboPlates.

## What changed

- Bite Wound tracker keeps source spell metadata at Spell ID 556234.
- The applied target debuff is now correctly identified as Aura ID 706654.
- Bloodfang Bite's live tooltip explicitly states that it creates Bite Wound [Spell ID 706654].
- Ascension DB confirms 706654 is the 10-second Bite Wound target debuff.
- ElvUI target-frame whitelist routing now uses the applied aura ID.
- TurboPlates whitelist/blacklist routing now uses the applied aura ID.
- beta.41 authoritative Nameplates ON/OFF behavior is otherwise unchanged.
- WeakAuras behavior is unchanged.

## Focused live test

1. Keep Bite Wound selected as Debuff / Unit: Target.
2. Set HUD OFF, Target Frame ON, Nameplates OFF and save.
3. Apply Bloodfang Bite. Bite Wound must be absent from TurboPlates and visible on the ElvUI target frame.
4. Re-enable Nameplates, save and apply again. Bite Wound must return to TurboPlates.
5. No Bite Wound WeakAura should be created.

## Safety rules

- Data identity fix only; no custom aura scanning.
- No custom WeakAuras trigger Lua.
- No `WeakAuras.Add`.
- Stable/main remains untouched.

Author: Retreat
