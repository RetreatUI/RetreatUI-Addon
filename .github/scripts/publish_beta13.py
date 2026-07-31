from __future__ import annotations

import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path.cwd()
OLD_VERSION = "1.1.0-beta.12"
VERSION = "1.1.0-beta.13"
TAG = f"v{VERSION}"
ZIP_NAME = f"RetreatUI_v{VERSION}.zip"
REPO = os.environ.get("REPO", "RetreatUI/RetreatUI-Addon")


def run(*args: str, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(args), flush=True)
    return subprocess.run(
        args,
        cwd=ROOT,
        check=check,
        text=True,
        capture_output=capture,
    )


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8", newline="\n")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    if old not in content:
        raise RuntimeError(f"Expected hotfix anchor missing in {path}: {old[:100]!r}")
    write(path, content.replace(old, new, 1))


def bump_version(path: str) -> None:
    content = read(path)
    if OLD_VERSION not in content:
        raise RuntimeError(f"Expected {OLD_VERSION} in {path}")
    write(path, content.replace(OLD_VERSION, VERSION))


# Version metadata.
for file_name in (
    "RetreatUI/RetreatUI.toc",
    "RetreatUI_Classes/RetreatUI_Classes.toc",
    "RetreatUI/Loader.lua",
    "RetreatUI/Core/Version.lua",
    "README.md",
):
    bump_version(file_name)

# Validate the persisted RetreatUI profile instead of requiring every live ElvUI
# module to have completed its reload-only transition immediately.
elvui_path = "RetreatUI/Integrations/ElvUI.lua"
replace_once(
    elvui_path,
    '''function RUI:AreElvUINamePlatesDisabled()
  local E = ElvUI and unpack(ElvUI)
  if E and E.private and E.private.nameplates and E.private.nameplates.enable ~= false then return false end
  if E and E.db and E.db.nameplates and E.db.nameplates.enable ~= false then return false end

  local db = self:EnsureDB()
  return db.integrations and db.integrations.elvui
    and db.integrations.elvui.nameplatesDisabled == true
    and db.integrations.elvui.nameplateAddonDisableOK ~= false
end''',
    '''function RUI:AreElvUINamePlatesDisabled()
  local db = self:EnsureDB()
  local state = db.integrations and db.integrations.elvui
  if not state or state.nameplatesDisabled ~= true then return false end

  -- A separately loaded ElvUI NamePlates module can remain alive until the
  -- reload that completes installation. Validate the saved RetreatUI profile
  -- here and repair the live tables without turning that reload-only state into
  -- a fatal installer error.
  local profile = type(ElvDB) == "table"
    and type(ElvDB.profiles) == "table"
    and ElvDB.profiles.RetreatUI
  if type(profile) ~= "table" then return false end
  profile.nameplates = profile.nameplates or {}
  if profile.nameplates.enable ~= false then return false end

  local E = ElvUI and unpack(ElvUI)
  if E and E.private then DisablePrivateNamePlates(E.private) end
  if E and E.db then DisablePrivateNamePlates(E.db) end
  return true
end''',
)

# Bind the saved RetreatUI profile directly to the current character before any
# risky live refresh callbacks are invoked.
replace_once(
    elvui_path,
    '''  ApplyClassFontColor(profile, true)
  ElvDB.profiles[profileName] = profile

  local ok, err = pcall(function()''',
    '''  ApplyClassFontColor(profile, true)
  ElvDB.profiles[profileName] = profile

  ElvDB.profileKeys = ElvDB.profileKeys or {}
  if UnitName then
    local character = UnitName("player")
    local realm = GetRealmName and GetRealmName()
    local characterKey = character and realm and (character .. " - " .. realm) or character
    if characterKey and characterKey ~= "" then ElvDB.profileKeys[characterKey] = profileName end
  end

  local ok, err = pcall(function()''',
)

# If ElvUI throws while refreshing its currently loaded frames, keep the
# correctly persisted profile and finish activation on reload instead of
# reporting that the complete profile installation failed.
replace_once(
    elvui_path,
    '''  end)
  if not ok then return false, "Profile created, but activation failed: " .. tostring(err) end
  return true, "RetreatUI ElvUI profile installed; ElvUI NamePlates disabled, right chat panel preserved, and Loot/Trade chat windows removed"
end''',
    '''  end)
  if not ok then
    local persisted = type(ElvDB.profiles) == "table"
      and type(ElvDB.profiles[profileName]) == "table"
      and type(ElvDB.profiles[profileName].nameplates) == "table"
      and ElvDB.profiles[profileName].nameplates.enable == false
    if persisted then
      local db = self:EnsureDB()
      db.integrations.elvui = db.integrations.elvui or {}
      db.integrations.elvui.activationWarning = tostring(err)
      db.integrations.elvui.activationPendingReload = true
      return true, "RetreatUI ElvUI profile saved; live frame activation will finish after reload"
    end
    return false, "Profile creation failed: " .. tostring(err)
  end
  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.activationWarning = nil
  db.integrations.elvui.activationPendingReload = nil
  return true, "RetreatUI ElvUI profile installed; ElvUI NamePlates disabled, right chat panel preserved, and Loot/Trade chat windows removed"
end''',
)

# Preserve the real module error in the installer's bottom status line.
modules_path = "RetreatUI/Core/Modules.lua"
replace_once(
    modules_path,
    '''      if not record or record.version ~= self.version or record.state ~= "success" then
        problems[#problems + 1] = definition.label .. " was not installed successfully"
      elseif definition.validate then''',
    '''      if not record or record.version ~= self.version or record.state ~= "success" then
        local detail = record and tostring(record.message or "") or ""
        problems[#problems + 1] = detail ~= ""
          and (definition.label .. ": " .. detail)
          or (definition.label .. " was not installed successfully")
      elseif definition.validate then''',
)

# Hotfix changelog.
version_path = "RetreatUI/Core/Version.lua"
content = read(version_path)
content = content.replace(
    'summary = "Global trinket tracking and a new user-supplied ElvUI unit-frame baseline.",',
    'summary = "Critical ElvUI installer hotfix for the v1.1 beta.",',
    1,
)
content = content.replace(
    '  changes = {\n',
    '  changes = {\n'
    '    "Fixed the installer incorrectly reporting a failed ElvUI profile when live ElvUI refresh work only needed the required reload.",\n'
    '    "The RetreatUI ElvUI profile is now assigned directly to the current character before frame refresh callbacks run.",\n'
    '    "Installer failures now include the original module error instead of only showing a generic FAILED state.",\n',
    1,
)
write(version_path, content)

# README current-beta note.
readme = read("README.md")
needle = "The current beta includes:\n"
if needle in readme:
    readme = readme.replace(
        needle,
        needle + "\n- Critical ElvUI installer validation and reload handling hotfix\n",
        1,
    )
write("README.md", readme)

# Static validation.
for toc in ("RetreatUI/RetreatUI.toc", "RetreatUI_Classes/RetreatUI_Classes.toc"):
    if f"## Version: {VERSION}" not in read(toc):
        raise RuntimeError(f"Version validation failed for {toc}")

elvui = read(elvui_path)
required_markers = (
    "activationPendingReload = true",
    "ElvDB.profileKeys[characterKey] = profileName",
    "Validate the saved RetreatUI profile",
)
for marker in required_markers:
    if marker not in elvui:
        raise RuntimeError(f"ElvUI hotfix marker missing: {marker}")

# Lua 5.1 syntax validation for all addon Lua files.
for lua_file in sorted(list((ROOT / "RetreatUI").rglob("*.lua")) + list((ROOT / "RetreatUI_Classes").rglob("*.lua"))):
    run("luac5.1", "-p", str(lua_file))

changed_files = [
    "RetreatUI/RetreatUI.toc",
    "RetreatUI_Classes/RetreatUI_Classes.toc",
    "RetreatUI/Loader.lua",
    "RetreatUI/Core/Version.lua",
    "RetreatUI/Core/Modules.lua",
    "RetreatUI/Integrations/ElvUI.lua",
    "README.md",
]

run("git", "config", "user.name", "RetreatUI Release Bot")
run("git", "config", "user.email", "actions@users.noreply.github.com")
run("git", "add", *changed_files)
status = run("git", "status", "--porcelain", capture=True).stdout.strip()
if status:
    run("git", "commit", "-m", f"Publish RetreatUI v{VERSION} ElvUI installer hotfix")
    source_sha = run("git", "rev-parse", "HEAD", capture=True).stdout.strip()
    run("git", "push", "origin", "HEAD:main")
else:
    source_sha = run("git", "rev-parse", "HEAD", capture=True).stdout.strip()

# Build the exact public archive with both addon folders at the ZIP root.
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

notes = ROOT / ".beta13-release-notes.md"
notes.write_text(
    "## Critical ElvUI installer hotfix\n\n"
    "- Fixes the installer incorrectly marking the ElvUI Profile as FAILED when the profile was saved correctly but a live ElvUI refresh required reload.\n"
    "- Assigns the RetreatUI ElvUI profile directly to the current character before running frame refresh callbacks.\n"
    "- Validates the persisted RetreatUI profile and repairs live nameplate settings without treating reload-only state as fatal.\n"
    "- Shows the original module error in the installer when a real installation failure occurs.\n\n"
    "All beta.12 HUD, trinket, ElvUI baseline and target-of-target changes are preserved.\n",
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
