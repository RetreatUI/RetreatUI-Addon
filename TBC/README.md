# RetreatUI – TBC Classic Anniversary

This directory is the unreleased development staging area for the TBC Classic Anniversary version of RetreatUI.

## Product split

- Conquest of Azeroth remains in the existing RetreatUI addon package.
- TBC Classic Anniversary is a separate addon implementation with the same RetreatUI layout and visual contract.
- The launcher will expose both products, but TBC installation remains disabled until the first test build is ready.

## Canonical spell database

The generated database under `TBC/Data/generated` contains:

- 3,261 Wowhead TBC-validated player ability and talent-rank rows
- every rank from all nine TBC talent trees
- 73 race-specific racial spell rows
- 34 passive trinket-to-proc mappings
- class-specific CSV files plus a combined all-spells catalog
- an audit list of 134 non-TBC source candidates excluded after Wowhead validation
- zero unresolved records inside the canonical catalog

Wowhead TBC tooltip data is canonical for names, descriptions, ranks and source links. LibSpellDB supplies curated ability/rank enumeration and tracking metadata. WoWSims TBC talent-tree data supplies every talent node and rank spell ID.

## First supported HUD

Feral Druid DPS is the first target.

Initial scope:

- centered Energy bar
- five Combo Point indicators
- Main row for rotational and offensive abilities
- Utility row for defensive and utility abilities
- race-filtered learned racial abilities on the appropriate row
- maximum nine icons on the first Main line
- target aura tracking for Rake, Rip, Mangle and Faerie Fire
- Clearcasting and Tiger's Fury tracking
- equipped trinket icons and on-use cooldown tracking
- passive trinket proc, stack, duration and internal-cooldown tracking when a verified mapping exists
- Cat Form state detection
- RetreatUI dark styling, borders, spacing and font rules
- automatic character macro for Feral powershifting

## Powershift macro

On a Druid, RetreatUI creates or repairs a character-specific macro named `RUI Powershift` outside combat:

```text
#showtooltip
/cancelaura Cat Form
/cast !Cat Form
```

The macro is created automatically after login and is kept on the exact body above. The player chooses the keybind by dragging it from the macro window to an action bar. If every character macro slot is occupied, RetreatUI prints a warning. After freeing a slot, `/ruitbc macro` creates it manually.

## Package staging

The folders under `TBC/Package` are intended to become the roots of the future TBC release ZIP:

- `RetreatUI`
- `RetreatUI_Classes`

No release or launcher manifest points at this staging package yet.

## Client

Target client: TBC Classic Anniversary 2.5.6 (`## Interface: 20506`).
