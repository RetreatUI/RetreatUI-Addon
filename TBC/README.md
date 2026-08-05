# RetreatUI – TBC Classic Anniversary

This directory is the unreleased development staging area for the TBC Classic Anniversary version of RetreatUI.

## Product split

- Conquest of Azeroth remains in the existing RetreatUI addon package.
- TBC Classic Anniversary is a separate addon implementation with the same RetreatUI layout and visual contract.
- The launcher will expose both products, but TBC installation remains disabled until the first test build is ready.

## First supported HUD

Feral Druid DPS is the first target.

Initial scope:

- centered Energy bar
- five Combo Point indicators
- Main row for rotational and offensive abilities
- Utility row for defensive and utility abilities
- maximum nine icons on the first Main line
- target aura tracking for Rake, Rip, Mangle and Faerie Fire
- Clearcasting and Tiger's Fury tracking
- Cat Form state detection
- RetreatUI dark styling, borders, spacing and font rules

## Package staging

The folders under `TBC/Package` are intended to become the roots of the future TBC release ZIP:

- `RetreatUI`
- `RetreatUI_Classes`

No release or launcher manifest points at this staging package yet.

## Client

Target client: TBC Classic Anniversary 2.5.5 (`## Interface: 20505`).
