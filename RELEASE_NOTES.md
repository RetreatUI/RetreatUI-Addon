# RetreatUI v1.1.7-beta.8

This prerelease hardens the CoA WeakAuras migration and replaces the two-page CoA installer with the clean step-by-step flow used by RetreatUI TBC.

## WeakAura HUD fixes

- Removed GameTooltip scraping from live WeakAura row selection. Ascension's GameTooltipMods can expose nil tooltip lines while the hidden scanner is building a spell tooltip; class HUD curation now uses the RetreatUI spell/class data directly instead.
- Resource packages now generate only the primary power that can actually be active for the current class instead of pre-creating Mana, Rage, Focus, Energy, Runic Power and Fury placeholders.
- Native secondary resources now generate only the configured representation (bar or segments). Guardian therefore keeps Energy plus Battle Momentum segments instead of a long list of inactive resource auras.
- Reinstalling a class HUD clears old Resource children first so beta.3-beta.7 placeholder resource auras do not survive upgrades.
- Bloodmage now has an explicit compact TBC-style Main/Utility curation profile and Blood Bond no longer falls back to a question-mark icon.
- Class State / stance / form trackers use the requested ElvUF_Player anchor: BOTTOMRIGHT to TOPRIGHT, X -17, Y +1.
- General WeakAuras continue to own Trinkets plus Buffs & Procs. The retired native Trinket HUD is no longer exposed as a separate installer component.

## Clean CoA installer

- Replaced the modular two-page install screen with a TBC-style one-step-at-a-time installer.
- Each component has its own page, status panel and apply button, with Back / Next navigation and progress markers for every step.
- The WeakAuras page installs the shared General package together with only the active CoA class package.
- Optional integrations such as TurboPlates, MobSpells, Details and DBM can be skipped without blocking the rest of setup.

## Existing combat HUD geometry

- Buffs & Procs: X 0 / Y -83.
- Secondary/custom resources: X 0 / Y -118.
- Primary resource: X 0 / Y -152, 360x16.
- Main: X 0 / Y -183, 38px icons, 1px spacing.
- Utility: X 0 / Y -224, 32px icons, 1px spacing.
- Trinkets: ElvUF_Player, BOTTOMRIGHT to TOPRIGHT, X -17 / Y +1.
- State / stance / form anchor: ElvUF_Player, BOTTOMRIGHT to TOPRIGHT, X -17 / Y +1.

This is a Beta / prerelease build for live verification before promotion to Stable.

Author: Retreat
