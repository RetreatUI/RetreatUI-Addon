from __future__ import annotations

import os
import subprocess
import zipfile
from pathlib import Path

ROOT = Path.cwd()
OLD_VERSION = "1.1.0-beta.13"
VERSION = "1.1.0-beta.14"
TAG = f"v{VERSION}"
ZIP_NAME = f"RetreatUI_v{VERSION}.zip"
REPO = os.environ.get("REPO", "RetreatUI/RetreatUI-Addon")


def run(*args: str, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(args), flush=True)
    return subprocess.run(args, cwd=ROOT, check=check, text=True, capture_output=capture)


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8", newline="\n")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    if old not in content:
        raise RuntimeError(f"Expected patch anchor missing in {path}: {old[:120]!r}")
    write(path, content.replace(old, new, 1))


def bump(path: str) -> None:
    content = read(path)
    if OLD_VERSION not in content:
        raise RuntimeError(f"Expected {OLD_VERSION} in {path}")
    write(path, content.replace(OLD_VERSION, VERSION))


for path in (
    "RetreatUI/RetreatUI.toc",
    "RetreatUI_Classes/RetreatUI_Classes.toc",
    "RetreatUI/Loader.lua",
    "RetreatUI/Core/Version.lua",
    "README.md",
):
    bump(path)

# Replace the sparse party aura export with the complete Ascension-ElvUI 7.27
# fields required by Configure_Auras and AuraFilter. Keep the supplied 20px
# debuff size and RetreatUI font.
profile_path = "RetreatUI/Profiles/ElvUI.lua"
replace_once(
    profile_path,
    '''      party = {
        debuffs = {
          sizeOverride = 20,
        },
        growthDirection = "DOWN_RIGHT",''',
    '''      party = {
        buffs = {
          enable = false,
          perrow = 4,
          numrows = 1,
          attachTo = "FRAME",
          anchorPoint = "LEFT",
          countFont = "Fira Sans Heavy",
          countFontOutline = "OUTLINE",
          countFontSize = 12,
          durationPosition = "CENTER",
          clickThrough = false,
          sortMethod = "TIME_REMAINING",
          sortDirection = "DESCENDING",
          minDuration = 0,
          maxDuration = 300,
          priority = "Blacklist,TurtleBuffs",
          sizeOverride = 0,
          xOffset = 0,
          yOffset = 0,
        },
        debuffs = {
          enable = true,
          perrow = 4,
          numrows = 1,
          attachTo = "FRAME",
          anchorPoint = "RIGHT",
          countFont = "Fira Sans Heavy",
          countFontOutline = "OUTLINE",
          countFontSize = 12,
          durationPosition = "CENTER",
          clickThrough = false,
          sortMethod = "TIME_REMAINING",
          sortDirection = "DESCENDING",
          minDuration = 0,
          maxDuration = 300,
          priority = "Blacklist,RaidDebuffs,CCDebuffs,Dispellable,Whitelist",
          sizeOverride = 20,
          xOffset = 0,
          yOffset = 0,
        },
        smartAuraPosition = "DISABLED",
        growthDirection = "DOWN_RIGHT",''',
)

integration_path = "RetreatUI/Integrations/ElvUI.lua"
repair_code = r'''
local ELVUI_AURA_REPAIR_REVISION = 1
local AURA_REQUIRED_DEFAULTS = {
  perrow = 4,
  numrows = 1,
  attachTo = "FRAME",
  anchorPoint = "TOPLEFT",
  countFont = "Fira Sans Heavy",
  countFontOutline = "OUTLINE",
  countFontSize = 12,
  durationPosition = "CENTER",
  clickThrough = false,
  sortMethod = "TIME_REMAINING",
  sortDirection = "DESCENDING",
  minDuration = 0,
  maxDuration = 300,
  priority = "",
  sizeOverride = 0,
  xOffset = 0,
  yOffset = 0,
}

local PARTY_BUFF_DEFAULTS = {
  enable = false,
  perrow = 4,
  numrows = 1,
  attachTo = "FRAME",
  anchorPoint = "LEFT",
  countFont = "Fira Sans Heavy",
  countFontOutline = "OUTLINE",
  countFontSize = 12,
  durationPosition = "CENTER",
  clickThrough = false,
  sortMethod = "TIME_REMAINING",
  sortDirection = "DESCENDING",
  minDuration = 0,
  maxDuration = 300,
  priority = "Blacklist,TurtleBuffs",
  sizeOverride = 0,
  xOffset = 0,
  yOffset = 0,
}

local PARTY_DEBUFF_DEFAULTS = {
  enable = true,
  perrow = 4,
  numrows = 1,
  attachTo = "FRAME",
  anchorPoint = "RIGHT",
  countFont = "Fira Sans Heavy",
  countFontOutline = "OUTLINE",
  countFontSize = 12,
  durationPosition = "CENTER",
  clickThrough = false,
  sortMethod = "TIME_REMAINING",
  sortDirection = "DESCENDING",
  minDuration = 0,
  maxDuration = 300,
  priority = "Blacklist,RaidDebuffs,CCDebuffs,Dispellable,Whitelist",
  sizeOverride = 20,
  xOffset = 0,
  yOffset = 0,
}

local function FillMissingAuraFields(aura, defaults)
  if type(aura) ~= "table" then return false end
  local changed = false
  for key, value in pairs(defaults or AURA_REQUIRED_DEFAULTS) do
    if aura[key] == nil then
      aura[key] = value
      changed = true
    end
  end
  return changed
end

local function RepairAuraProfile(profile)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local units = profile.unitframe.units
  local changed = false

  -- Sparse ElvUI exports omit values equal to defaults. Ascension-ElvUI 7.27
  -- directly indexes these fields and does not tolerate nil values after a raw
  -- profile table is installed, so complete every aura table that RetreatUI
  -- supplies before ElvUI creates or refreshes unit frames.
  for _, unit in pairs(units) do
    if type(unit) == "table" then
      for _, auraType in ipairs({"buffs", "debuffs"}) do
        local aura = unit[auraType]
        if type(aura) == "table" then
          changed = FillMissingAuraFields(aura, AURA_REQUIRED_DEFAULTS) or changed
        end
      end
    end
  end

  units.party = units.party or {}
  local party = units.party
  party.smartAuraPosition = party.smartAuraPosition or "DISABLED"
  party.buffs = party.buffs or {}
  party.debuffs = party.debuffs or {}
  changed = FillMissingAuraFields(party.buffs, PARTY_BUFF_DEFAULTS) or changed
  changed = FillMissingAuraFields(party.debuffs, PARTY_DEBUFF_DEFAULTS) or changed
  return changed
end

function RUI:RepairElvUIAuraProfiles(refreshLive)
  local changed = false
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    changed = RepairAuraProfile(ElvDB.profiles.RetreatUI) or changed
  end

  local E = ElvUI and unpack(ElvUI)
  local currentProfile
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if currentProfile == "RetreatUI" and E and E.db then
    changed = RepairAuraProfile(E.db) or changed
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.auraRepairRevision = ELVUI_AURA_REPAIR_REVISION
  db.integrations.elvui.auraRepairVersion = self.version

  if refreshLive and changed and E then
    if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
    if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  end
  return true, changed and "ElvUI unit-frame aura settings repaired" or "ElvUI unit-frame aura settings verified"
end
'''

replace_once(
    integration_path,
    'local STANCE_BAR_MOVER = "TOPLEFT,ElvUIParent,BOTTOMLEFT,649,32"\n',
    'local STANCE_BAR_MOVER = "TOPLEFT,ElvUIParent,BOTTOMLEFT,649,32"\n' + repair_code + '\n',
)

replace_once(
    integration_path,
    '''  local profile = self:DeepCopy(self.ElvUIProfile)
  profile.movers = profile.movers or {}''',
    '''  local profile = self:DeepCopy(self.ElvUIProfile)
  RepairAuraProfile(profile)
  profile.movers = profile.movers or {}''',
)

replace_once(
    integration_path,
    '''    if E and E.data and E.data.SetProfile then E.data:SetProfile(profileName) end
    self:DisableElvUINamePlates()''',
    '''    if E and E.data and E.data.SetProfile then E.data:SetProfile(profileName) end
    if E and E.db then RepairAuraProfile(E.db) end
    self:DisableElvUINamePlates()''',
)

# Run the persisted-profile repair as the integration file loads. RetreatUI is
# loaded after ElvUI but before PLAYER_LOGIN, so this repairs beta.12/beta.13
# SavedVariables before secure party frames are created.
content = read(integration_path)
append_marker = '''  return true, "Fira Sans Heavy applied to " .. table.concat(results, ", ")
end
'''
if append_marker not in content:
    raise RuntimeError("Could not locate ElvUI integration end marker")
content = content.replace(
    append_marker,
    append_marker + '''
-- Emergency migration for profiles installed by beta.12 or beta.13.
if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" and ElvDB.profiles.RetreatUI then
  pcall(RUI.RepairElvUIAuraProfiles, RUI, false)
end
''',
    1,
)
write(integration_path, content)

# Add the repair to manual troubleshooting too, although normal beta.14 login
# repairs the persisted profile automatically.
loader_path = "RetreatUI/Loader.lua"
replace_once(
    loader_path,
    '''    {"Target of Target", "ApplyTargetTargetFrame", false},
    {"Castbars and action bars", "ApplyElvUIHUDPolish", true},''',
    '''    {"Target of Target", "ApplyTargetTargetFrame", false},
    {"ElvUI aura settings", "RepairElvUIAuraProfiles", true},
    {"Castbars and action bars", "ApplyElvUIHUDPolish", true},''',
)

# Changelog.
version_path = "RetreatUI/Core/Version.lua"
version = read(version_path)
version = version.replace(
    'summary = "Critical ElvUI installer hotfix for the v1.1 beta.",',
    'summary = "Emergency repair for incomplete Ascension-ElvUI unit-frame aura settings.",',
    1,
)
version = version.replace(
    '  changes = {\n',
    '  changes = {\n'
    '    "Fixed the party-frame Lua error caused by missing Ascension-ElvUI maxDuration, minDuration and priority aura fields.",\n'
    '    "Automatically repairs RetreatUI profiles created by beta.12 and beta.13 before party frames are created.",\n'
    '    "Completed every sparse unit-frame buff/debuff table with safe Ascension-ElvUI 7.27 defaults.",\n',
    1,
)
write(version_path, version)

readme = read("README.md")
needle = "The current beta includes:\n"
if needle in readme:
    readme = readme.replace(
        needle,
        needle + "\n- Emergency repair for incomplete Ascension-ElvUI party and unit-frame aura settings\n",
        1,
    )
write("README.md", readme)

# Static checks against the exact crash fields and migration timing.
checks = {
    profile_path: [
        'priority = "Blacklist,RaidDebuffs,CCDebuffs,Dispellable,Whitelist"',
        'minDuration = 0',
        'maxDuration = 300',
    ],
    integration_path: [
        'function RUI:RepairElvUIAuraProfiles(refreshLive)',
        'pcall(RUI.RepairElvUIAuraProfiles, RUI, false)',
        'RepairAuraProfile(profile)',
    ],
}
for path, markers in checks.items():
    data = read(path)
    for marker in markers:
        if marker not in data:
            raise RuntimeError(f"Missing validation marker in {path}: {marker}")

for toc in ("RetreatUI/RetreatUI.toc", "RetreatUI_Classes/RetreatUI_Classes.toc"):
    if f"## Version: {VERSION}" not in read(toc):
        raise RuntimeError(f"Version validation failed for {toc}")

for lua_file in sorted(list((ROOT / "RetreatUI").rglob("*.lua")) + list((ROOT / "RetreatUI_Classes").rglob("*.lua"))):
    run("luac5.1", "-p", str(lua_file))

changed = [
    "RetreatUI/RetreatUI.toc",
    "RetreatUI_Classes/RetreatUI_Classes.toc",
    "RetreatUI/Loader.lua",
    "RetreatUI/Core/Version.lua",
    "RetreatUI/Profiles/ElvUI.lua",
    "RetreatUI/Integrations/ElvUI.lua",
    "README.md",
]
run("git", "config", "user.name", "RetreatUI Release Bot")
run("git", "config", "user.email", "actions@users.noreply.github.com")
run("git", "add", *changed)
status = run("git", "status", "--porcelain", capture=True).stdout.strip()
if status:
    run("git", "commit", "-m", f"Publish RetreatUI v{VERSION} emergency ElvUI aura repair")
    source_sha = run("git", "rev-parse", "HEAD", capture=True).stdout.strip()
    run("git", "push", "origin", "HEAD:main")
else:
    source_sha = run("git", "rev-parse", "HEAD", capture=True).stdout.strip()

zip_path = ROOT / ZIP_NAME
if zip_path.exists():
    zip_path.unlink()
run("zip", "-qr", str(zip_path), "RetreatUI", "RetreatUI_Classes")
with zipfile.ZipFile(zip_path) as archive:
    names = archive.namelist()
    if not any(name.startswith("RetreatUI/") for name in names):
        raise RuntimeError("RetreatUI folder missing from ZIP")
    if not any(name.startswith("RetreatUI_Classes/") for name in names):
        raise RuntimeError("RetreatUI_Classes folder missing from ZIP")

notes = ROOT / ".beta14-release-notes.md"
notes.write_text(
    "## Emergency Ascension-ElvUI repair\n\n"
    "Beta.12 and beta.13 could install a sparse party debuff table that omitted fields required by Ascension-ElvUI 7.27. This caused repeated `Auras.lua` errors and could prevent party frames from appearing.\n\n"
    "- Adds the complete Ascension-ElvUI aura fields required by `Configure_Auras` and `AuraFilter`.\n"
    "- Automatically repairs existing RetreatUI profiles before `PLAYER_LOGIN`, including profiles created by beta.12 and beta.13.\n"
    "- Preserves existing non-missing aura settings and only fills required nil values.\n"
    "- Keeps the supplied 20px party debuff size and all beta.13 installer fixes.\n\n"
    "Replace both RetreatUI addon folders, enable them again, log in and allow the normal reload requested by the installer.\n",
    encoding="utf-8",
)

existing = run("gh", "release", "view", TAG, "--repo", REPO, check=False, capture=True)
if existing.returncode == 0:
    run("gh", "release", "delete", TAG, "--repo", REPO, "--yes", "--cleanup-tag")
run(
    "gh", "release", "create", TAG, ZIP_NAME,
    "--repo", REPO,
    "--target", source_sha,
    "--title", f"RetreatUI v{VERSION}",
    "--notes-file", str(notes),
    "--prerelease",
)
print(f"Published {TAG} from {source_sha} with {ZIP_NAME}")
