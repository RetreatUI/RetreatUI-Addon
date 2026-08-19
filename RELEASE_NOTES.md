# RetreatUI v1.1.7-beta.34 - Charge and Debuff Data Test

This prerelease keeps the verified beta.33 native WeakAuras paths and narrows the next test to two issues found during live Bloodmage testing: charge presentation while a recharge is running, and a missing curated Spell ID for Bite Wound.

## What changed

- Charge tracking now mirrors Ascension WeakAuras 5.21.2's own `Charge Tracking` template more closely.
- For a tracker with Charges enabled, the base icon has cooldown swipe disabled while at least one charge remains.
- A native WeakAuras condition enables cooldown swipe only when the trigger's `charges == 0`.
- Charge count continues to use WeakAuras' native `%s` dynamic text.
- The already verified non-charge cooldown behavior remains unchanged.
- Adds a verified Bloodmage metadata override for Bite Wound: Spell/Aura ID `556234`, Unit `target`, native Debuff tracking.
- Makes Bloodsores (`805591`, max 5 stacks) the explicit Bloodmage stacks proof case.

## Expected charge behavior - Rotclaw

Rotclaw is a verified two-charge ability. After updating its managed WeakAura:

- 2/2 charges: show `2`.
- After spending one charge: keep showing `1` rather than letting a recharge cooldown replace the charge count.
- At 0 charges: show the cooldown/recharge swipe until a charge returns.
- As charges recover: return to `1`, then `2`.

This mirrors the native Ascension WeakAuras charge template behavior and uses no custom trigger Lua.

## Focused Bloodmage test

1. Update to beta.34 through the Beta launcher channel.
2. Open `/rui tracker` and rebuild/update Rotclaw with Charges + `Stacks / charges` enabled.
3. Confirm 2 -> 1 charge remains visible after spending one charge, and cooldown swipe is only used at zero charges.
4. Find Bite Wound. It should now show Spell ID `556234` instead of `?`.
5. Configure Bite Wound as Debuff, Unit: Target, Duration enabled. Do not enable Stacks for Bite Wound.
6. Build/import the managed Bite Wound aura and confirm it appears while your Bite Wound debuff is active on the target.
7. For stacks, use Bloodsores instead. Configure Proc + Stacks + `Stacks / charges`, build/import, and confirm its 1-5 native stack count is shown.
8. Confirm rebuilds still open WeakAuras Update instead of creating duplicates.
9. Confirm there are no Lua errors.

## Safety rules

- No `WeakAuras.Add`.
- No custom trigger Lua.
- No custom WeakAuras decoder.
- No automatic import/update acceptance.
- No automatic deletion of existing WeakAuras.
- Resource and Summon / Pet remain profile-only in this build.

Do not promote this build to Stable.

Author: Retreat
