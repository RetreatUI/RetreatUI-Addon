# RetreatUI v1.1.7-beta.29 - Native WeakAuras Import Test

This prerelease is the first controlled bridge from Tracker Builder data into the exact Project Ascension WeakAuras 5.21.2 build supplied from the launcher environment.

## Scope

- Keeps all beta.27 Tracker Builder selection/editor/group-layout data.
- Keeps the beta.28 Ascension addon profile adapters.
- Adds `/ruiwatest` as an isolated proof-of-concept command.
- Selects the first currently saved Tracker Builder entry that has Cooldown enabled.
- Builds one sparse native WeakAuras icon display using the exact Ascension `Cooldown Progress (Spell)` trigger fields.
- Uses the selected Spell ID directly with `use_exact_spellName = true`.
- Uses the tracker icon size for the generated display.
- Uses `showAlways` for this proof so the icon remains visible while the cooldown swipe can still be tested.
- Sends `{ d = display, c = {}, v = 2000 }` to `WeakAuras.Import()`.
- Lets WeakAuras run its own `PreAdd`, native defaults, options loading and import/update window.

## Safety rules

This test does **not** call `WeakAuras.Add`.

This test does **not** decode or encode a WeakAuras string itself.

This test does **not** use custom trigger Lua.

This test does **not** automatically accept/install the aura. The user must confirm it in WeakAuras' own import window.

If any required native WeakAuras API is missing, RetreatUI reports a normal chat error and stops before opening an import.

## Test steps

1. Update to beta.29 through the Beta launcher channel.
2. Run `/rui tracker` and ensure at least one selected tracker has Cooldown enabled.
3. Close the Tracker Builder.
4. Run `/ruiwatest` while out of combat.
5. Confirm WeakAuras opens its normal import/update window without a Lua error.
6. Verify the imported preview shows the selected ability name/icon and a native `Cooldown Progress (Spell)` trigger.
7. Accept the import manually.
8. Close WeakAuras and verify the icon is visible and reacts to the spell cooldown.
9. Open `/wa` and confirm the aura is a normal editable WeakAura with no custom trigger code.

Do not promote this build to Stable.

Author: Retreat
