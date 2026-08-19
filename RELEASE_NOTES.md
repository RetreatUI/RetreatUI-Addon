# RetreatUI v1.1.7-beta.33 - Native Tracker Types Test

This prerelease keeps the fully verified managed WeakAura identity/update flow from beta.32 and extends the same native WeakAuras 5.21.2 generator to additional Tracker Builder types.

## Native WeakAuras types in this build

- Cooldown
- Cooldown + Buff duration
- Buff
- Proc
- Debuff
- Stacks
- Charges

Resource and Summon / Pet remain valid RetreatUI profile data but are deliberately not generated as WeakAuras in this build.

## Implementation rules

- Buff / Proc use WeakAuras' native `aura2` HELPFUL trigger.
- Debuff uses native `aura2` HARMFUL tracking on the tracker-selected unit.
- Stacks use native aura state and WeakAuras' `%s` dynamic count text.
- Charges use the native `Cooldown Progress (Spell)` state and `%s` count text.
- Cooldown + Buff keeps the exact live-verified two-trigger behavior from beta.30-beta.32.
- Managed class/spell ID + UID reuse remains unchanged, so rebuilding a tracker uses WeakAuras' Update flow.
- Unsupported Resource/Summon selections are ignored only when another supported native type is also selected; a Resource/Summon-only tracker is refused safely.

## Safety rules

- No `WeakAuras.Add`.
- No custom trigger Lua.
- No custom WeakAuras decoder.
- No automatic import/update acceptance.
- No automatic deletion of user or legacy WeakAuras.
- Ambiguous Buff/Proc + Debuff combinations are refused instead of generating contradictory triggers.
- Building is blocked in combat.

## Focused test pass

1. Update to beta.33 through the Beta launcher channel.
2. Confirm the existing managed Apotheosis aura can still be rebuilt/updated and still shows active buff duration followed by cooldown.
3. In Tracker Builder choose a learned ability/proc with a player buff, configure Buff or Proc and press `Build WeakAura`.
4. Import manually and confirm it appears only while the aura is active and shows duration.
5. Choose a target debuff, set Unit: Target + Debuff, build/import and confirm it follows the debuff on the target.
6. For an aura that stacks, enable Stacks + `Stacks / charges`, build/import and confirm the native stack count is visible.
7. For an ability with charges, enable Charges + `Stacks / charges`, build/import and confirm the native charge count changes when charges are consumed/recovered.
8. Rebuild one of the above after changing icon size and confirm WeakAuras opens Update rather than creating a duplicate.
9. Confirm there are no Lua errors.

Do not promote this build to Stable.

Author: Retreat
