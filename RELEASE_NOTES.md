# RetreatUI v1.1.7-beta.35 - WeakAuras Count Layout Test

This prerelease keeps the live-verified beta.34 trigger behavior and changes only the presentation of native stack/charge count text.

## What changed

- Rotclaw charge logic is unchanged.
- Native `%s` stack/charge count text is now anchored to `INNER_BOTTOMRIGHT` with a small inset.
- Cooldown/recharge text remains centered, so it no longer covers the stack/charge value.
- The same corner layout is used for both spell charges and real aura stacks.
- Bite Wound ID/debuff metadata from beta.34 remains intact.
- No automatic WeakAuras import/update acceptance.

## Focused test

1. Update to beta.35 through the Beta launcher channel.
2. Rebuild/update the managed Rotclaw WeakAura.
3. Confirm the charge count is clearly visible in the lower-right corner while cooldown/recharge text remains centered.
4. Spend one charge and confirm the value `1` remains readable while recharge is running.
5. Spend both charges and confirm the cooldown/recharge display does not overlap the corner count area.
6. Confirm there are no Lua errors.

## Safety rules

- No `WeakAuras.Add`.
- No custom trigger Lua.
- No custom WeakAuras decoder.
- Trigger semantics are unchanged from beta.34.

Do not promote this build to Stable.

Author: Retreat
