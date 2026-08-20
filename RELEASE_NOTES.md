# RetreatUI v1.1.7-beta.44 - Aura Destination Hotfix

This prerelease fixes the beta.43 regression where curated CoA tracker records without a source Spell ID could lose their Professional Audit effect identity before ElvUI/TurboPlates destination routing.

## Fixed

- Curated class records with no hand-pinned source ID now resolve against the generated Professional Audit by a unique same-class spell name.
- Ambiguous duplicate names are never auto-linked.
- The resolved audit record supplies the canonical source `spellID` and high-confidence `effectID` / `auraID`.
- Existing beta.43 saved selections with name-only keys are enriched and migrated to their canonical `spell:<sourceID>` key.
- Existing destination choices and tracking types are preserved during migration.
- Target Frame and Nameplates routing can once again consume the saved applied aura ID.

## Primary verification case

- Bite Wound resolves from the curated name-only record to source Spell ID `556234` and applied target Aura ID `706654` without restoring a handwritten metadata override.

## Unchanged safety rules

- Professional Audit remains the source of effect identity.
- No custom aura runtime engine.
- No custom WeakAuras trigger Lua.
- No direct WeakAuras insertion API.
- Stable/main remains untouched pending live-test approval.

Author: Retreat
