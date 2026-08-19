# RetreatUI v1.1.7-beta.32 - Managed WeakAuras Update Test

This prerelease keeps the proven beta.31 Tracker Editor -> native WeakAuras flow and adds stable managed identity so rebuilding the same tracker updates the same WeakAura instead of creating another copy.

## What changed

- Adds a deterministic managed WeakAura id per Tracker Builder entry using class + spell name + Spell ID.
- Stores the managed WeakAura id/uid mapping in `RetreatUIDB.weakAurasManaged`.
- Reuses the existing WeakAura uid when the managed aura already exists.
- Reuses the remembered uid if the import was prepared previously but not yet accepted.
- Keeps the proven native Cooldown and Cooldown + Buff duration trigger paths unchanged.
- Keeps `Build WeakAura` inside Configure Tracker.
- Existing beta.29-beta.31 `RetreatUI Test - ...` auras are not automatically deleted or modified.

## Expected behavior

The first build of a tracker should open WeakAuras' normal Import flow for a stable name such as:

`RetreatUI - Bloodmage - Apotheosis [804203]`

After that aura has been imported, changing the Tracker Builder configuration and pressing `Build WeakAura` again should open WeakAuras' native Update flow for that same aura rather than creating another entry.

## Safety rules

- No automatic deletion of existing or legacy WeakAuras.
- No `WeakAuras.Add`.
- No custom WeakAuras transmission decoder.
- No custom trigger Lua.
- No automatic import/update acceptance.
- WeakAuras 5.21.2 performs its own native import/update validation.
- Building remains blocked in combat.

## Test steps

1. Update to beta.32 through the Beta launcher channel.
2. Existing `RetreatUI Test - Apotheosis` proof auras may be deleted manually in `/wa` if desired; RetreatUI will not touch them.
3. Run `/rui tracker` and edit Apotheosis.
4. Press `Build WeakAura` and manually Import the new stable `RetreatUI - Bloodmage - Apotheosis [804203]` aura.
5. Reopen `/rui tracker`, edit Apotheosis and change icon size.
6. Press `Build WeakAura` again.
7. Confirm WeakAuras presents an Update for the existing managed Apotheosis aura rather than a second new import.
8. Accept the update and verify the icon size changed.
9. Confirm only one managed `RetreatUI - Bloodmage - Apotheosis [804203]` entry exists.
10. Confirm cooldown + active buff duration still work and there are no Lua errors.

Do not promote this build to Stable.

Author: Retreat
