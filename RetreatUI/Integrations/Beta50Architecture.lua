local RUI = RetreatUI
if not RUI then return end

local RETIRED_MODULES = {
  classHUD = true,
  partyTrackers = true,
  trinketHUD = true,
  generalWeakAuras = true,
  classWeakAuras = true,
}

local OriginalIsInstallerModuleEnabled = RUI.IsInstallerModuleEnabled
if type(OriginalIsInstallerModuleEnabled) == "function" then
  function RUI:IsInstallerModuleEnabled(key)
    if RETIRED_MODULES[key] then return false end
    return OriginalIsInstallerModuleEnabled(self, key)
  end
end

-- Compatibility redirects only. Nothing in beta.50 should open the legacy HUD
-- editor or Tracker Builder as a separate window.
function RUI:OpenHUDEditor()
  return self:OpenHUDBarUnlockMode()
end
function RUI:ToggleHUDEditor()
  return self:ToggleHUDBarUnlockMode()
end
function RUI:OpenTrackerBuilder()
  return self:OpenRetreatUI("hud")
end
function RUI:ToggleTrackerBuilder()
  return self:OpenRetreatUI("hud")
end

function RUI:InstallGeneralWeakAuras()
  return false, "Prebuilt WeakAuras were retired. Build your HUD from RetreatUI > HUD."
end
function RUI:InstallClassWeakAuras()
  return false, "Prebuilt class WeakAuras were retired. Build your HUD from RetreatUI > HUD."
end

local OriginalInstallRetreatStyle = RUI.InstallRetreatStyle
if type(OriginalInstallRetreatStyle) == "function" then
  function RUI:InstallRetreatStyle(styleKey, resolution)
    local ok, message, results = OriginalInstallRetreatStyle(self, styleKey, resolution)
    if ok then
      local db = self:EnsureDB()
      db.installer = db.installer or {}
      db.installer.initialCompleted = true
      db.installer.completedVersion = self.version
      db.installer.architecture = "profile-shell"
      db.installer.moduleSelections = db.installer.moduleSelections or {}
      db.installer.moduleSelections.classHUD = false
      db.installer.moduleSelections.partyTrackers = false
      db.installer.moduleSelections.trinketHUD = false
      if type(self.DeactivateAllHUD) == "function" then pcall(self.DeactivateAllHUD, self) end
    end
    return ok, message, results
  end
end

local function Migrate()
  local db = RUI:EnsureDB()
  db.installer = db.installer or {}
  db.installer.moduleSelections = db.installer.moduleSelections or {}
  db.installer.moduleSelections.classHUD = false
  db.installer.moduleSelections.partyTrackers = false
  db.installer.moduleSelections.trinketHUD = false
  db.installer.architecture = "profile-shell"
  db.integrations = db.integrations or {}
  db.integrations.beta50 = db.integrations.beta50 or {}
  if db.integrations.beta50.legacyHUDRetired ~= true then
    if type(RUI.DeactivateAllHUD) == "function" then pcall(RUI.DeactivateAllHUD, RUI) end
    db.integrations.beta50.legacyHUDRetired = true
    db.integrations.beta50.legacyHUDRetiredVersion = RUI.version
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() Migrate() end)

RUI._beta50ArchitectureLoaded = true
RUI.beta50ArchitectureSchema = 1
