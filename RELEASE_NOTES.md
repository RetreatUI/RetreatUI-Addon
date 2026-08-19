# RetreatUI v1.1.7-beta.30 - Native WeakAuras Duration Test

This prerelease extends the beta.29 native WeakAuras proof-of-concept to validate combined cooldown + active buff duration tracking against the exact Project Ascension WeakAuras 5.21.2 build.

## What changed

- Keeps the proven beta.29 native `WeakAuras.Import()` path.
- Prefers a selected Tracker Builder entry with both Cooldown and Buff enabled.
- Uses the Tracker Builder aura name as a native `aura2` player-buff trigger.
- Uses the selected Spell ID as a native `Cooldown Progress (Spell)` trigger.
- Orders the native triggers the same way as WeakAuras' own cooldown+buff template: Buff first, Cooldown second.
- Uses `disjunctive = "any"` and native active-trigger selection so the icon can show active buff progress while the buff exists and fall back to cooldown progress afterward.
- Keeps the display as a normal editable WeakAura.

## Safety rules

This test does **not** call `WeakAuras.Add`.

This test does **not** decode or encode WeakAuras transmissions itself.

This test does **not** use custom trigger Lua.

This test does **not** automatically accept/install the aura. The user must confirm it in WeakAuras' own import window.

## Test steps

1. Update to beta.30 through the Beta launcher channel.
2. In `/rui tracker`, ensure Apotheosis or another tracker has both Cooldown and Buff enabled and has Duration enabled.
3. Close Tracker Builder and run `/ruiwatest` out of combat.
4. Confirm WeakAuras opens its normal import window for the new `Cooldown + Buff` test aura.
5. Import it manually.
6. In `/wa`, confirm Trigger 1 is the player HELPFUL aura and Trigger 2 is `Cooldown Progress (Spell)`.
7. Close `/wa`, activate the ability and confirm the icon switches to the active buff duration instead of only showing the long cooldown.
8. When the buff expires, confirm the icon returns to cooldown progress.
9. Confirm there are no Lua errors.

Do not promote this build to Stable.

Author: Retreat
