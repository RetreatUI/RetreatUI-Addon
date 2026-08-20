# RetreatUI v1.1.7-beta.43 - Full CoA Spell Effect Audit

This prerelease replaces the one-off beta.42 aura correction with a generated, class-wide source-to-runtime effect audit for Conquest of Azeroth.

## What changed

- Professional Audit coverage now loads for all 21 CoA classes.
- Source/cast `spellID` remains the canonical ability identity.
- Ascension cooldown/replacement identity is kept separately as `cooldownID`.
- High-confidence applied runtime states are stored separately as `effectID` / `auraID`.
- Secondary `[Spell ID ...]` tooltip references are classified instead of being assumed to be auras.
- Transform, teaching, triggered-cast, summon and other non-aura relationships remain audit metadata and are not automatically routed as buffs/debuffs.
- Curated class records inherit generated high-confidence effect identity by source Spell ID, so presentation/layout data cannot hide the audit mapping.
- Tracker Builder persists the separated source, cooldown and effect identities.
- ElvUI target debuff routing and TurboPlates nameplate routing continue to consume `auraID` first.
- Aura-based WeakAura builds use the high-confidence applied `auraID` while cooldown triggers continue to use the source/runtime cooldown identity.
- Handwritten Bite Wound / Bloodsores effect overrides are retired.

## Verification cases

- Bite Wound: source Spell ID `556234`, applied target Aura ID `706654`.
- Bloodsores: source Spell ID `805591`, applied Bloodsore runtime effect `805592`.
- Non-aura secondary references remain relations only and do not become ElvUI/TurboPlates/WeakAura aura IDs automatically.

## Live-test focus

1. Open Tracker Builder on several CoA classes and confirm source spell IDs remain the ability IDs.
2. For audited debuffs, confirm ElvUI Target Frame and TurboPlates receive the applied aura/effect ID rather than the cast/source ID.
3. For cooldown + aura trackers, confirm the cooldown follows the ability/runtime cooldown ID while the native WeakAuras aura trigger follows the applied aura ID.
4. Confirm unrelated tooltip references such as transforms, teaching, triggered casts and summons do not create automatic aura tracking.
5. Confirm no duplicate trackers, Lua errors or regressions in the beta.42 destination ON/OFF behavior.

## Safety rules

- No custom aura runtime engine.
- No custom WeakAuras trigger Lua.
- No `WeakAuras.Add`.
- Native WeakAuras Import flow only.
- Stable/main remains untouched until live testing is approved.

Author: Retreat
