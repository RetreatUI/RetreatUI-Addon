# Changelog

All notable changes to RetreatUI are documented in this file.

The format is based on **Keep a Changelog** and follows semantic versioning where possible.

---

## [1.1.7-beta.21] - 2026-08-19

### Added

- Added the next launcher-ready CoA test build based on the validated beta.20 profile/import branch.
- Added a focused in-game validation plan for ElvUI, Details, TurboPlates and the General/class WeakAura packages.

### Changed

- Bumped RetreatUI, RetreatUI Classes and the optional RetreatUI Buff Manager to `1.1.7-beta.21`.
- Marked the build as a prerelease for the existing RetreatUI Launcher Beta channel.
- Kept DBM outside the CoA package and kept Buff Manager separate and disabled by default.

### Preserved

- beta.19 WeakAura runtime performance protections.
- beta.18 chat ownership protections.
- beta.17 protected-frame and secure-taint protections.
- The validated beta.20 static ElvUI, Details and WeakAura import contracts.

---

## [1.1.4] - 2026-08-06

### Changed

- Added a distinct orange-red tank no-aggro state for caster and mana-user TurboPlates without replacing their normal blue color.
- Moved the Guardian stance tracker six pixels upward to clear the resource bar.
- Tightened RetreatUI party-frame name and health text sizing and alignment.

### Fixed

- Added a global HUD duplicate guard across every supported class and HUD row.
- Removed duplicate spell entries such as Unleash Pestilence in the Knight of Xoroth Hellfire HUD.
- Improved TurboPlates threat-state refresh reliability when its normal mana overlay repaints a nameplate.
- Prevented party-frame name and health text from overlapping in the packaged RetreatUI ElvUI profile.

---

## [1.0.9] - 2026-07-23

### Changed

- Moved interrupt and taunt abilities to the Utility Bar across all supported classes
- Moved Bloodmage Lunge from the Main Rotation Bar to the Utility Bar
- Removed Bloodfang Bite from the Bloodmage Main Rotation Bar while retaining target debuff tracking
- Removed Moon Gaze from the Bloodmage HUD
- Updated both RetreatUI and RetreatUI Classes to version 1.0.9

### Fixed

- Corrected the Bloodmage Bloodfang Bite spell ID used by the class data and detection logic
- Improved consistency between Main Rotation and Utility Bar layouts across supported classes

---

## [1.0.8] - 2026-07-23

### Added

- Animated Blood support for Bloodmage
- Bloodmage target debuff tracking
- Eternal Curse support
- Additional talent-aware spell tracking

### Changed

- Major Bloodmage HUD overhaul
- Improved Cultist HUD and spell tracking
- Improved Venomancer HUD and spell tracking
- Updated class framework for improved flexibility
- Improved installer and UI integration

### Fixed

- Lunge tracking
- Combat lockdown issues
- HUD visibility while the World Map is open
- Multiple UI alignment issues
- Various bug fixes and quality-of-life improvements

---

## [1.0.1] - 2026-07-20

### Initial Public Release

- Initial release of RetreatUI
- Knight of Xoroth support
- Installer
- ElvUI integration
- TurboPlates integration
