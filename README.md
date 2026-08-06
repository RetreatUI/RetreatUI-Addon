# RetreatUI

**One UI. Two games. Built for Retreat.**

RetreatUI is a compact World of Warcraft interface project for:

- **Project Ascension: Conquest of Azeroth**
- **The Burning Crusade Classic / Anniversary**

The project combines class-aware HUDs, addon profiles, installation tooling and the RetreatUI Launcher into one maintained setup. The goal is a dark, compact, centre-focused interface with the information needed in combat and as little unnecessary clutter as possible.

---

## RetreatUI Launcher

The Windows launcher is the recommended way to install and maintain RetreatUI.

It supports separate game installations and **Stable / Beta** update channels, including:

- Automatic addon-folder detection
- One-click install and update
- Version and release-note display
- File validation
- Backups and rollback
- Downgrade protection
- Launcher self-updates with SHA-256 verification
- Direct game launch shortcuts

Launcher releases:

https://github.com/RetreatUI/RetreatUI-Launcher-Releases/releases/latest

---

# Conquest of Azeroth

RetreatUI for **Project Ascension: Conquest of Azeroth** is the mature branch of the project.

It replaces scattered class trackers and repetitive setup work with a native class-aware addon that detects learned abilities, talents, active class states, resources, buffs, cooldowns and relevant target debuffs.

The CoA package contains:

```text
RetreatUI/
RetreatUI_Classes/
```

Always install or update both folders together.

## CoA highlights

### Adaptive class HUDs

- Native HUD support for all 21 Conquest of Azeroth classes
- Learned-only Main Rotation, Utility, Defensive and racial tracking
- Dynamic rows that rebuild when abilities, talents or Character Advancement specializations change
- Active proc and buff icons with timers, stacks and actionable ability glows
- Curated player- and pet-applied target debuffs
- Dedicated tracking for stances, forms, Vows, Oaths, Aspects, Pestilences and other class systems
- Class-specific power bars, stack counters, timers and mechanic displays
- Native Pyromancer/Pyrolancer Heat and Ember tracking
- Necromancer Guardian and Zombie tracking
- Ascension resource and Totem Bar integration

### Per-class and per-build layouts

- Independent HUD profiles for detected classes and builds
- Saved positions and scale per supported HUD section
- Automatic build detection
- `/rui hud` visual editor
- Automatic migration from older RetreatUI layouts

### Party systems

RetreatUI includes native party utility and interrupt tracking for relevant abilities, including combat resurrection, dispels, external defensives, group defensives, immunities, taunts and interrupts.

### Buff Manager

- Supported buff-family detection
- Normal/Greater spell selection
- Equivalent and exclusive-family handling
- Per-class user-selected keybinds
- Smart Buff target selection
- No forced default keybinds

### Global Trinket Tracker

Every supported class and build receives a compact tracker for equipped trinkets in slots 13 and 14, including cooldowns, matching procs, stacks, glow and tooltips.

### Integrations

- ElvUI
- TurboPlates
- MobSpells / NPC ability cooldown integration
- Details!
- Optional Deadly Boss Mods integration
- Combat-text styling
- LFG role-check automation

## Supported CoA classes

RetreatUI supports all 21 Conquest of Azeroth classes:

- Barbarian
- Bloodmage
- Chronomancer
- Cultist
- Felsworn
- Guardian
- Knight of Xoroth
- Necromancer
- Primalist
- Pyromancer
- Ranger
- Reaper
- Runemaster
- Starcaller
- Stormbringer
- Sun Cleric
- Templar
- Tinker
- Venomancer
- Witch Doctor
- Witch Hunter

## CoA requirements

- Project Ascension: Conquest of Azeroth
- `RetreatUI_Classes` from the same release
- ElvUI
- TurboPlates v1.4.5
- MobSpells v1.3
- Details!

Deadly Boss Mods is optional.

## CoA commands

```text
/rui                 Open the installer
/rui hud             Open the HUD Editor
/rui build           Show the detected build profile
/rui utility         Open Party Utility settings
/rui buffs           Open Buff Manager assignments
/rui keybinds        Open Buff Manager keybinds
/rui automation      Open automation settings
/rui status          Show addon, class and installation status
/rui changelog       Show the current in-game changelog
/rui repair          Refresh RetreatUI-managed systems
/rui reset           Reset the installer for the current class
```

---

# The Burning Crusade

RetreatUI TBC is the new TBC Classic / Anniversary implementation and is currently under active development and testing.

The TBC addon lives separately from the CoA addon:

```text
RetreatUI_TBC/
```

This separation keeps TBC profiles, SavedVariables and class logic independent from the Conquest of Azeroth installation.

## TBC direction

The TBC package is being built as a complete installable UI rather than only a collection of class WeakAuras.

The current foundation includes:

- Native RetreatUI TBC core
- In-game installer
- Separate TBC SavedVariables
- Automatic class detection
- ElvUI profile integration
- Details! profile integration
- Plater profile import framework
- WeakAuras import framework
- Class HUD framework
- Stable/Beta-ready packaging

### Druid HUD

Druid is the first active TBC class implementation and includes the initial foundation for:

- Cat Form HUD
- Bear Form HUD
- Caster-form HUD
- Energy, Rage and Mana display
- Combo Points
- Learned-spell filtering
- Rotational ability rows
- Utility ability row
- Cooldown tracking
- Target-debuff timers
- Automatic form switching

The target is a complete Feral DPS/Tank-ready setup while retaining support for the rest of the Druid toolkit.

### TBC profiles

RetreatUI TBC is designed to install and maintain a coordinated setup for:

- RetreatUI class HUDs
- ElvUI
- WeakAuras
- Plater
- Details!

The serialized WeakAuras and Plater payloads are still being completed and tested before the TBC package is considered feature-complete.

### TBC command

```text
/ruitbc              Open the RetreatUI TBC installer
```

### TBC status

**Early Beta / active development**

The first package line is `0.1.0-beta.x`. Expect rapid changes while the installer, profiles and Druid HUD are validated in the live TBC client.

---

# Installation

## Recommended: RetreatUI Launcher

Use the launcher to select the game and update channel. CoA and TBC are treated as separate installations.

https://github.com/RetreatUI/RetreatUI-Launcher-Releases/releases/latest

## Manual CoA installation

1. Download the required RetreatUI ZIP from Releases.
2. Close Project Ascension completely.
3. Delete the existing `RetreatUI` and `RetreatUI_Classes` folders.
4. Extract both new folders into `Interface/AddOns`.
5. Enable RetreatUI, RetreatUI Classes and the required integrations.
6. Log in and complete the RetreatUI installer when prompted.

Do not merge new CoA releases into old addon folders. Replace both folders completely.

## Manual TBC installation

During the TBC beta period, use the TBC-specific prerelease/package and install `RetreatUI_TBC` into the TBC Classic `Interface/AddOns` folder.

Complete the in-game installer with `/ruitbc`.

---

# Release channels

## CoA Stable

**RetreatUI v1.1.3**

The current public stable release reorganizes class HUDs so learned offensive and rotational abilities remain on Main while defensive and utility abilities remain on Utility. It also includes verified Eternal Bloodmage classifications, additional class cooldown coverage and Ascension-focused stability improvements.

## CoA Beta

Beta releases are used for live testing before promotion to Stable.

## TBC Beta

**RetreatUI TBC 0.1.0-beta.x**

TBC is currently a development/beta product. The Druid implementation, installer and profile framework are the first focus before expansion to additional classes.

---

# Downloads

Latest CoA stable release:

https://github.com/RetreatUI/RetreatUI-Addon/releases/latest

All stable and beta addon releases:

https://github.com/RetreatUI/RetreatUI-Addon/releases

RetreatUI Launcher:

https://github.com/RetreatUI/RetreatUI-Launcher-Releases/releases/latest

---

# Discord

Development updates, test builds, class discussions and issue reports are handled through the official RetreatUI Discord:

https://discord.gg/uzZFrtbVab

---

# Reporting issues

For CoA reports, please include the affected class/build, ability or mechanic, screenshot, expected behaviour, Stable/Beta channel and `/rui status` output when relevant.

For TBC beta reports, include the class/spec or form, the affected HUD/profile component, screenshot, expected behaviour and installed TBC beta version.

---

# Project structure

```text
RetreatUI/           Conquest of Azeroth core
RetreatUI_Classes/   Conquest of Azeroth class data
RetreatUI_TBC/       The Burning Crusade implementation
.github/workflows/   Validation and release automation
```

Addon author: **Retreat**

---

# License

RetreatUI is proprietary. All rights reserved unless otherwise stated.

Third-party components retain their original licences and copyright notices where applicable.
