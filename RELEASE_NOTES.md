# RetreatUI v1.1.7-beta.36 - Clean Charge Visual Test

This prerelease keeps the live-verified Rotclaw charge behavior from beta.35 and changes only icon presentation.

## What changed

- Rotclaw charge trigger logic is unchanged.
- Native `%s` stack/charge count stays in the lower-right corner.
- Charge/stack count uses compact white outlined text.
- For charge abilities, WeakAuras/OmniCC countdown text is hidden while at least one charge remains.
- At zero charges, the corner count is hidden and cooldown countdown text may appear in the center when `Cooldown text` is enabled.
- This removes the large recharge number that visually dominated the icon at 1/2 charges.
- Real aura stacks continue to use the same lower-right count layout.

## Expected Rotclaw presentation

- 2 charges: clean icon + small `2` in the lower-right.
- 1 charge while recharging: clean icon + small `1` in the lower-right; no giant recharge number over the icon.
- 0 charges: charge count disappears and cooldown/recharge countdown may display in the center.
- When a charge returns: return to the clean corner-count presentation.

## Safety rules

- No WeakAuras trigger semantics changed.
- No `WeakAuras.Add`.
- No custom trigger Lua.
- No custom decoder.
- No automatic import/update acceptance.

Do not promote this build to Stable.

Author: Retreat
