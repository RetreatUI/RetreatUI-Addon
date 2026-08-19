# RetreatUI v1.1.7-beta.37 - Native Charge Text Test

This prerelease keeps the live-verified Rotclaw charge behavior unchanged and replaces external cooldown countdown text with native WeakAuras text for charge trackers.

## What changed

- Rotclaw charge trigger logic is unchanged.
- Native `%s` charge/stack count remains in the lower-right corner.
- Charge/stack count uses compact white outlined text.
- Charge trackers now keep WeakAuras/OmniCC cooldown-frame countdown numbers disabled at all times.
- While 1 or more charges remain, only the corner charge count is shown.
- At zero charges, the corner count is hidden and a small centered native WeakAuras `%p` timer may appear when `Cooldown text` is enabled.
- The centered native timer uses compact white outlined text instead of external OmniCC styling.
- Real aura stacks keep the same lower-right count layout.
- No branded third-party UI references are included in the CoA build.

## Expected Rotclaw presentation

- 2 charges: clean icon + small `2` in the lower-right.
- 1 charge while recharging: clean icon + small `1` in the lower-right; no large recharge number.
- 0 charges: charge count disappears and a small centered native WeakAuras timer shows the recharge when enabled.
- When a charge returns: return to the clean corner-count presentation.

## Safety rules

- No WeakAuras trigger semantics changed.
- No `WeakAuras.Add`.
- No custom trigger Lua.
- No custom decoder.
- No automatic import/update acceptance.

Do not promote this build to Stable.

Author: Retreat
