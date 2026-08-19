# RetreatUI v1.1.7-beta.21 — Naowh CoA Test

This prerelease is the first launcher-ready test build of the Naowh-style RetreatUI layout for Project Ascension: Conquest of Azeroth.

## Test scope

- Builds directly on the validated beta.20 CoA profile/import branch.
- Keeps the supplied 1440p and 1080p ElvUI exports and the validated Details profile import path.
- Keeps the static WeakAuras package architecture: General package plus all 21 supported CoA class packages.
- Keeps the beta.20 WeakAuras installer contract based on WeakAuras' own decode libraries plus `WeakAuras.Add()` / `WeakAuras.GetData()` verification.
- Keeps TurboPlates integration and the RetreatUI CoA NPC spell/cooldown data.
- Keeps the compact installer flow: ElvUI -> Details -> TurboPlates -> General WeakAuras -> Class WeakAura -> Reload.
- DBM is intentionally not part of the RetreatUI CoA package.
- RetreatUI Buff Manager remains a separate optional addon and is disabled by default.

## Naowh UI reference

The visual and structural reference is the Warmane **Naowh UI Project (Retail-like)** by Lunminas/joaodaspica and Nethanos. The original project standardizes the UI around a shared ElvUI/WeakAuras/Details look and four class WeakAura groups. RetreatUI ports that philosophy to CoA rather than attempting to run the old Wrath addon builds directly on Ascension.

See `NAOWH_UI_CREDITS.md` for attribution.

## Preserved CoA safety work

- beta.19 WeakAuras runtime performance protections remain intact.
- beta.18 chat ownership protections remain intact.
- beta.17 protected-frame and secure-taint protections remain intact.
- Existing CoA class/resource/state handling from beta.20 remains unchanged for this first visual test build.

## What to test in game

1. Install/update through the RetreatUI Beta channel after the R2 prerelease is published.
2. Fully close Project Ascension before launching the game again.
3. Run `/rui` and apply the installer from start to finish.
4. Verify ElvUI positioning, unit frames, action bars, minimap, chat and raid/party frames at the selected resolution.
5. Verify the Details profile is present and active.
6. Verify TurboPlates loads normally and NPC ability/cooldown data still works.
7. Verify General WeakAuras and the detected CoA class package install without duplicate HUD elements.
8. Verify the class UI layout, resources, procs, state/stance icons and cooldowns in combat.
9. Report any layout mismatch separately from any class/spell logic problem so the port can be iterated without replacing the whole package.

This is a Beta / prerelease test build and must not be promoted to Stable until the Vol'jin in-game pass is clean.

Author: Retreat
