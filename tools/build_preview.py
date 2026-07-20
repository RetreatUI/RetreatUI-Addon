from __future__ import annotations

import re
import zipfile
from pathlib import Path

VERSION = "1.0.2-dev.10"
ROOT = Path(__file__).resolve().parents[1]


def replace_required(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Required build patch was not found in {path}: {old[:80]!r}")
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def patch_versions() -> None:
    toc = ROOT / "RetreatUI" / "RetreatUI.toc"
    classes_toc = ROOT / "RetreatUI_Classes" / "RetreatUI_Classes.toc"
    loader = ROOT / "RetreatUI" / "Loader.lua"
    classes_loader = ROOT / "RetreatUI_Classes" / "Loader.lua"

    for path in (toc, classes_toc):
        text = path.read_text(encoding="utf-8")
        text = re.sub(r"(?m)^## Version: .+$", f"## Version: {VERSION}", text, count=1)
        path.write_text(text, encoding="utf-8")

    text = loader.read_text(encoding="utf-8")
    text = re.sub(r'\bor "[^"]+"', f'or "{VERSION}"', text, count=1)
    loader.write_text(text, encoding="utf-8")

    text = classes_loader.read_text(encoding="utf-8")
    text = re.sub(r'\bor "[^"]+"', f'or "{VERSION}"', text, count=1)
    classes_loader.write_text(text, encoding="utf-8")

    version_file = ROOT / "RetreatUI" / "Core" / "Version.lua"
    text = version_file.read_text(encoding="utf-8")
    new_block = f'''RUI.changelog = {{
  version = RUI.version,
  title = "RetreatUI v{VERSION}",
  summary = "Preview pass applying the Knight of Xoroth decision-HUD framework to Cultist and Venomancer.",
  changes = {{
    "Rebuilt Cultist and Venomancer around one dynamically centred main decision row, matching Knight of Xoroth.",
    "Added race-racial cooldown tracking as a mandatory shared baseline for both preview modules.",
    "Added Cultist Insanity thresholds, Dreadnought, Total Madness, summon and active-duration preview logic.",
    "Added Venomancer Exposed Flesh, Carapace, venom selection, Deadly Sting, Tome and active-duration preview logic.",
    "Added exact cleanup for Ascension's CoAResourceOrb Insanity tracker.",
    "Replaced the generic installer sidebar logo with softly blended class artwork.",
  }},
}}
'''
    text, count = re.subn(
        r"RUI\.changelog = \{.*?\n\}\nlocal updateFrame",
        new_block + "local updateFrame",
        text,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise RuntimeError("Could not replace the Version.lua changelog block")
    version_file.write_text(text, encoding="utf-8")


def patch_resource_cleanup() -> None:
    path = ROOT / "RetreatUI" / "Integrations" / "Cleanup.lua"
    replace_required(
        path,
        '  "CoAResourceSegmentBar",\n',
        '  "CoAResourceSegmentBar",\n  "CoAResourceOrb",\n',
    )


def patch_installer_sidebar() -> None:
    path = ROOT / "RetreatUI" / "Installer" / "Installer.lua"
    old = '''  -- The logo uses a transparent, feathered texture so it blends into the sidebar
  -- instead of appearing as a square image placed on top of it.
  local logoGlow = frame.sidebar:CreateTexture(nil, "BORDER")
  logoGlow:SetTexture("Interface\\\\Buttons\\\\WHITE8X8")
  logoGlow:SetSize(124, 96)
  logoGlow:SetPoint("TOP", 0, -12)
  logoGlow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.055)

  local logo = frame.sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture("Interface\\\\AddOns\\\\RetreatUI\\\\Media\\\\RetreatUI_Logo.tga")
  logo:SetSize(126, 104)
  logo:SetPoint("TOP", 0, -8)
  logo:SetTexCoord(0.025, 0.975, 0.025, 0.975)
'''
    new = '''  -- Class artwork replaces the generic logo. Four sidebar-coloured gradient
  -- overlays feather the image into the panel so no hard rectangular edge is visible.
  local visual = theme.installer or {}
  local logoGlow = frame.sidebar:CreateTexture(nil, "BORDER")
  logoGlow:SetTexture("Interface\\\\Buttons\\\\WHITE8X8")
  logoGlow:SetSize(176, 108)
  logoGlow:SetPoint("TOP", 0, -5)
  logoGlow:SetVertexColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.10)

  local logo = frame.sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(visual.artwork or visual.icon or "Interface\\\\AddOns\\\\RetreatUI\\\\Media\\\\RetreatUI_Logo.tga")
  logo:SetSize(176, 108)
  logo:SetPoint("TOP", 0, -5)
  local crop = visual.artworkCrop or {0, 1, 0, 1}
  logo:SetTexCoord(crop[1] or 0, crop[2] or 1, crop[3] or 0, crop[4] or 1)
  logo:SetAlpha(0.90)

  local function SidebarFade(point, relativePoint, width, height, orientation, fromAlpha, toAlpha, x, y)
    local fade = frame.sidebar:CreateTexture(nil, "OVERLAY")
    fade:SetTexture("Interface\\\\Buttons\\\\WHITE8X8")
    fade:SetSize(width, height)
    fade:SetPoint(point, logo, relativePoint, x or 0, y or 0)
    if fade.SetGradientAlpha then
      fade:SetGradientAlpha(orientation,
        theme.sidebar[1], theme.sidebar[2], theme.sidebar[3], fromAlpha,
        theme.sidebar[1], theme.sidebar[2], theme.sidebar[3], toAlpha)
    else
      fade:SetVertexColor(theme.sidebar[1], theme.sidebar[2], theme.sidebar[3], math.max(fromAlpha, toAlpha))
    end
    return fade
  end
  SidebarFade("LEFT", "LEFT", 34, 108, "HORIZONTAL", 1, 0, 0, 0)
  SidebarFade("RIGHT", "RIGHT", 34, 108, "HORIZONTAL", 0, 1, 0, 0)
  SidebarFade("TOP", "TOP", 176, 26, "VERTICAL", 1, 0, 0, 0)
  SidebarFade("BOTTOM", "BOTTOM", 176, 34, "VERTICAL", 0, 1, 0, 0)
'''
    replace_required(path, old, new)


def write_test_notes() -> None:
    notes = ROOT / f"TEST_NOTES_v{VERSION}.txt"
    notes.write_text(
        f"""RETREATUI v{VERSION} PREVIEW TESTS
========================================

CULTIST
- One centred main row contains rotational decisions, defensives, taunts, stops, utility, summons and the real race racial.
- Total Madness remains grey with no DISABLED/INACTIVE text until the aura is active.
- Entropic Slam highlights at 60+ Insanity; Dreadnought and Mass Nightmare highlight at 80+.
- Active Dreadnought, Abyssal Ward, Tentacle and Satiate appear as duration trackers.
- CoAResourceOrb should be hidden automatically.

VENOMANCER
- One centred main row contains active decisions and the real race racial.
- Exposed Flesh and Carapace counters use talent-aware caps.
- Deadly Sting highlights Hivebreak; shed abilities reflect Exposed Flesh; Barbed Stinger shows PULL while attached.
- Two active long-duration venoms and active defensive/proc durations appear above the row.

INSTALLER
- Sidebar uses class artwork instead of the generic RetreatUI logo.
- Gradient overlays should blend all four artwork edges into the sidebar.

This is intentionally a preview build. PREVIEW_MODE is enabled in Cultist/HUD.lua and Venomancer/HUD.lua.
""",
        encoding="utf-8",
    )


def validate_no_obvious_placeholders() -> None:
    for relative in (
        "RetreatUI_Classes/Cultist/HUD.lua",
        "RetreatUI_Classes/Venomancer/HUD.lua",
    ):
        text = (ROOT / relative).read_text(encoding="utf-8")
        if "DISABLED" in text or '"INACTIVE"' in text:
            raise RuntimeError(f"Forbidden Total Madness status text remains in {relative}")


def package() -> Path:
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    archive = dist / f"RetreatUI_v{VERSION}.zip"
    if archive.exists():
        archive.unlink()
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for folder_name in ("RetreatUI", "RetreatUI_Classes"):
            folder = ROOT / folder_name
            for path in sorted(folder.rglob("*")):
                if path.is_file():
                    zf.write(path, path.relative_to(ROOT).as_posix())
        notes = ROOT / f"TEST_NOTES_v{VERSION}.txt"
        zf.write(notes, notes.name)
    return archive


def main() -> None:
    patch_versions()
    patch_resource_cleanup()
    patch_installer_sidebar()
    write_test_notes()
    validate_no_obvious_placeholders()
    archive = package()
    print(archive)


if __name__ == "__main__":
    main()
