# RetreatUI TBC beta audit

## Confirmed working foundation

- Separate `RetreatUI_TBC` addon and SavedVariables
- `/ruitbc` installer entry point
- Class detection
- Native Druid HUD/runtime foundation
- Cat, Bear and caster-form switching
- Energy, Rage, Mana and Combo Point handling
- Learned-spell filtering and target-debuff timer framework
- Basic ElvUI and Details configuration tables
- Separate TBC beta packaging workflow

## Blocking items before a public beta

- Embed and validate the real Plater profile payload
- Embed and validate General WeakAuras
- Embed and validate Druid Resource WeakAuras
- Embed and validate Druid Main WeakAuras
- Embed and validate Druid Utility WeakAuras
- Expand the ElvUI profile from a minimal merge into the approved RetreatUI layout
- Expand the Details profile into the approved RetreatUI setup
- Validate all Druid spell IDs, ranks, forms, cooldowns and debuff ownership in the live TBC client
- Verify installer rollback/retry behaviour

## Installer safety

The installer must never mark the setup complete when a selected component failed or its payload is missing. Rows are only marked `READY` when both the required addon and RetreatUI data are present.

Author: Retreat
