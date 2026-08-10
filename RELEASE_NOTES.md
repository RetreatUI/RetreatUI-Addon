# RetreatUI v1.1.7-beta.3

This prerelease moves RetreatUI's visible Conquest of Azeroth combat HUD from native/custom Lua frames into WeakAuras while keeping the existing RetreatUI class databases as the source of truth.

## WeakAuras HUD migration

- Adds the universal `RetreatUI - General` package with Trinkets and Buffs & Procs.
- Adds a generated `RetreatUI - <Class>` package for the active CoA class with Resource, Main, Utility, State and Target groups.
- Main and Utility remain data-driven by the existing 21 class `Data.lua` catalogues, including learned-spell checks, Ascension talent/replacement resolution, cooldowns, charges, tracked buff durations and racials.
- Buffs & Procs remain active-only at X 0 / Y -83 and also catch short player-owned temporary weapon/trinket procs.
- Primary resources remain 360x16 at X 0 / Y -152.
- Secondary/custom resources remain at X 0 / Y -118, using segmented displays for compact integer resources and bars for larger resources.
- Knight of Xoroth retains Demonfire, Hellfire Imp and Demon's Blood tracking in the existing Y -118 resource lane; Hellfire Imp summons retain the 60-second combat-log lifetime tracking used by the old HUD.
- Main remains X 0 / Y -183 with 38px icons and 1px spacing.
- Utility remains X 0 / Y -224 with 32px icons and 1px spacing.
- Target debuffs remain player-owned and use the existing target-debuff location and 180x16 bar format.
- Class states/forms/aspects/oaths/formations remain beside the trinket row.
- General trinkets use the confirmed CoA WeakAura anchor: `ElvUF_Player`, BOTTOMRIGHT to TOPRIGHT, X -17 / Y +1.

## Renderer ownership

- WeakAuras now owns the visible central combat HUD.
- The old BaselineHUD, AdvancedHUD and class HUD modules remain in the package as data/provider and rollback references, but their visible renderers are no longer activated.
- The old native RetreatUI trinket renderer is no longer started.
- Native Ascension custom-resource frames remain alive as hidden data sources only when RetreatUI needs to mirror values into WeakAuras.
- WeakAuras is now required for the RetreatUI Class HUD installer component.

## Testing note

This is the first full CoA renderer migration. The intended test is visual/mechanical parity: the same tracked information in the same RetreatUI locations, now rendered through WeakAuras. Test the active class after running the installer and reloading UI, with particular attention to custom resources, proc visibility, class states, target debuffs and talent/spec changes.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
