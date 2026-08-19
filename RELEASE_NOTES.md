# RetreatUI v1.1.7-beta.38 - Native Charge Visual Cleanup

This prerelease keeps the live-verified Rotclaw charge behavior unchanged and simplifies presentation so WeakAuras owns cooldown/duration display while RetreatUI only styles the native stack/charge count.

## What changed

- Rotclaw charge trigger logic is unchanged.
- Native `%s` charge/stack count remains in the lower-right corner.
- Charge/stack count uses compact white outlined text.
- Removed RetreatUI workarounds for external cooldown-number overlays.
- WeakAuras keeps its normal native cooldown/duration presentation.
- No special charge-only timer or custom display state is generated.
- Real aura stacks use the same lower-right count layout.
- Managed WeakAura identity/update behavior is unchanged.

## Expected Rotclaw presentation

- 2 charges: native icon with small `2` in the lower-right.
- 1 charge: native icon with small `1` in the lower-right.
- 0 charges: WeakAuras' normal cooldown/recharge presentation.
- No duplicate RetreatUI-generated cooldown text.

## Safety rules

- No WeakAuras trigger semantics changed.
- No `WeakAuras.Add`.
- No custom trigger Lua.
- No custom decoder.
- No automatic import/update acceptance.

Do not promote this build to Stable.

Author: Retreat
