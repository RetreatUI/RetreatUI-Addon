# RetreatUI

A compact, class-aware interface package built exclusively for **Project Ascension: Conquest of Azeroth**.

RetreatUI replaces scattered class trackers and repetitive setup work with one native addon that adapts to the character you are currently playing. It detects learned abilities, talents, active class states, resources, buffs, cooldowns and relevant target debuffs, then keeps the important information close to the centre of the screen without unnecessary clutter.

RetreatUI includes a complete core addon and a separate class-data addon:

```text
RetreatUI/
RetreatUI_Classes/
```

Always install or update both folders together.

---

## Highlights

### Adaptive class HUDs

- Native HUD support for all 21 Conquest of Azeroth classes
- Learned-only **Main Rotation**, **Utility**, **Defensive** and racial tracking
- Dynamic rows that rebuild when abilities, talents or Character Advancement specializations change
- Active proc and buff icons with timers, stacks and actionable ability glows
- Curated player- and pet-applied target debuffs instead of an unfiltered aura wall
- Dedicated tracking for stances, forms, Vows, Oaths, Aspects, Pestilences and similar class systems
- Class-specific power bars, stack counters, timers and mechanic displays
- Native Pyromancer/Pyrolancer Heat and five-segment Ember tracking
- Necromancer Guardian HUD with individual health bars, active Guardian counts and Zombie tracking
- Ascension resource and Totem Bar integration without requiring personal WeakAuras

### Per-class and per-build layouts

RetreatUI automatically creates separate HUD profiles for each detected class and build. Changing talents or specialization does not force every build to share the same layout.

- Independent saved positions and scale for each supported HUD section
- Automatic build detection from the live spellbook and talent state
- Automatic migration from older RetreatUI layouts
- `/rui hud` visual editor with draggable anchors and per-section scaling
- `/rui build` status command for the currently detected build profile
- Automatic HUD refresh after spellbook, talent and specialization changes

The normal update flow does not require a custom reset, restore or repair command. RetreatUI migrates only the components it manages.

### Party Utility and Interrupt Tracker

RetreatUI can display relevant party abilities directly beside the unit that owns them.

Party Utility supports:

- Combat resurrection
- Dispels
- External defensives
- Group defensives
- Immunities
- Taunts

Interrupts use a separate compact tracker below the active party frame:

- One row per detected interrupt
- Spell icon, player name and **READY**/cooldown status
- Ready interrupts remain at the top
- Active cooldowns are sorted by shortest remaining time
- Blood Elf Arcane Torrent support
- Automatically matches the width and position of the active party frame

Open Party Utility settings with `/rui utility`.

### Buff Manager and Smart Buff

- 58 supported buff families
- Automatic normal/Greater spell selection
- Exclusive-family and equivalent-buff handling
- Per-class user-selected keybinds with duplicate prevention
- Manual family keybinds remain available
- Smart Buff automatically finds the next valid party member
- Skips offline, dead, phased, invisible, out-of-range and already covered players
- No default keybinds are forced on the user

Open assignments with `/rui buffs` and keybinds with `/rui keybinds`.

### Global Trinket Tracker

Every supported class and build receives a compact two-slot tracker for equipped trinkets:

- Tracks inventory slots 13 and 14
- Uses the same icon size as the Buffs/Procs row
- Anchors to the upper-right area of the live player frame
- Grows toward the left
- Shows item cooldowns and matching active proc/buff durations
- Supports stacks, glow and native item tooltips
- Automatically shifts away from nearby unit frames to avoid overlap
- No separate mover or independent scaling system

### ElvUI baseline and managed migration

RetreatUI includes a maintained ElvUI baseline for:

- Player
- Target
- Target-of-target
- Pet
- Focus
- Party
- Raid and other supported unit frames
- Cast bars and reserved HUD spacing

The baseline is applied during installation or a required migration. RetreatUI does **not** reapply the full profile on every login and does not overwrite unrelated personal ElvUI settings.

Later manual ElvUI mover changes remain user-managed. Runtime updates only refresh the lightweight RetreatUI-managed polish needed for the current layout.

### Integrations and quality-of-life features

- ElvUI profile, unit-frame, cast-bar and cleanup integration
- TurboPlates styling and resource-aware nameplate support
- MobSpells/NPC ability cooldown integration
- Details! profile integration
- Optional Deadly Boss Mods integration
- Combat-text styling
- Automatic removal of only the unwanted Loot/Trade chat windows while preserving the normal right chat panel
- Native auto-accept for LFG role checks

Role-check automation never accepts dungeon queue confirmations or group invitations. Open its setting with `/rui automation`.

---

## Supported Classes

The current RetreatUI v1.1 beta line supports all 21 Conquest of Azeroth classes:

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

Class systems continue to be refined through public testing. Missing abilities, incorrect icons, inaccurate aura IDs and layout issues should be reported.

---

## Requirements

- Project Ascension: Conquest of Azeroth
- `RetreatUI_Classes` from the same RetreatUI release
- ElvUI
- TurboPlates v1.4.5
- MobSpells v1.3
- Details!

Deadly Boss Mods is supported as an optional integration.

WeakAuras is not required. Personal WeakAuras remain independent and are never imported, edited or removed by RetreatUI.

---

## Recommended Installation: RetreatUI Launcher

The Windows launcher is the easiest way to install and maintain RetreatUI.

Launcher features include:

- Stable and Beta update channels
- Automatic Project Ascension AddOns-folder detection
- One-click installation, updating and repair
- Automatic updates when Project Ascension is closed
- Version and release-note display
- Download and installed-file validation
- Automatic backups and rollback
- Hard downgrade protection
- Automatic launcher self-updates with SHA-256 verification
- Optional Project Ascension launch button

Download the public launcher here:

https://github.com/RetreatUI/RetreatUI-Launcher-Releases/releases/latest

The launcher only replaces:

```text
RetreatUI
RetreatUI_Classes
```

It never modifies WoW SavedVariables.

---

## Manual Installation

1. Download the required RetreatUI ZIP from the **Releases** page.
2. Close Project Ascension completely.
3. Delete the existing `RetreatUI` and `RetreatUI_Classes` folders.
4. Extract both new folders into `Interface/AddOns`.
5. Enable RetreatUI, RetreatUI Classes and the required addons.
6. Log into a supported class and complete the RetreatUI installer when prompted.

Existing RetreatUI settings, Buff Manager assignments, build profiles and managed positions migrate automatically whenever possible.

Do not merge a new release into old addon folders. Replace both folders completely.

---

## Commands

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

`/rui repair` and `/rui reset` are troubleshooting tools. They are not part of the normal update process.

---

## Release Channels

### Stable

**RetreatUI v1.0.11**

Use the Stable channel for the latest normal release.

### Beta

**RetreatUI v1.1.0-beta.14**

The current beta includes:

- Emergency repair for incomplete Ascension-ElvUI party and unit-frame aura settings

- Critical ElvUI installer validation and reload handling hotfix

- Automatic per-class/per-build HUD profiles
- The `/rui hud` visual editor
- Party Utility and the dedicated Party Interrupt Tracker
- Smart Buff and per-class Buff Manager keybinds
- Native Pyromancer/Pyrolancer resource tracking
- The global slot 13/14 Trinket Tracker
- The new user-supplied ElvUI unit-frame baseline
- Managed one-time migrations that preserve later personal mover changes
- Trinket tooltip and resolution-independent target-of-target fixes

Beta builds are available through the launcher's Beta channel or the repository's Releases page.

### Launcher

**RetreatUI Launcher v0.2.8**

---

## Downloads

Latest stable release:

https://github.com/RetreatUI/RetreatUI-Addon/releases/latest

All stable and beta releases:

https://github.com/RetreatUI/RetreatUI-Addon/releases

RetreatUI Launcher:

https://github.com/RetreatUI/RetreatUI-Launcher-Releases/releases/latest

---

## Discord

Development updates, test builds, class discussions and issue reports are handled through the official RetreatUI Discord:

https://discord.gg/uzZFrtbVab

---

## Reporting Issues

Please include:

- The affected class and build
- The ability, buff, debuff or mechanic involved
- A screenshot showing the problem
- The expected behaviour
- Whether the problem occurs on Stable or Beta
- The output from `/rui status` when relevant

---

## Current Addon Version

**RetreatUI v1.1.0-beta.14**

This version promotes the complete current addon source to `main`, restores native Trinket Tracker tooltips and anchors target-of-target relative to the target frame for resolution-independent placement.

---

## License

RetreatUI is proprietary. All rights reserved unless otherwise stated.

Third-party components retain their original licences and copyright notices where applicable.
