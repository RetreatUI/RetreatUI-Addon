local RUI = RetreatUI
if not RUI then return end

-- beta.20 ownership contract:
--   * WeakAuras owns class ability/proc/resource presentation.
--   * The native class package only keeps the CoA state/form/stance lane because
--     Ascension exposes several of those states outside normal WA spell triggers.
--   * Legacy beta.8-beta.19 class HUD roots and the duplicate native power bar
--     must never reactivate after a Naowh profile import.
--   * DBM is not part of the CoA installer anymore.

local currentTracker
local currentClass
local stateDriver
local stateTimerElapsed = 0

local LEGACY_RUNTIME_KEYS = {
  classHUD = true,
  trinketHUD = true,
  partyTrackers = true,
  unitframes = true,
  nameplates = true,
}

-- Events.lua asks the installer registry whether historical runtime owners should
-- auto-start. Keep normal installer modules untouched, but permanently decline
-- the old visual owners above so they cannot modify a correctly imported Naowh UI.
local previousIsInstallerModuleEnabled = RUI.IsInstallerModuleEnabled
if type(previousIsInstallerModuleEnabled) == "function" then
  function RUI:IsInstallerModuleEnabled(key)
    if LEGACY_RUNTIME_KEYS[key] then return false end
    return previousIsInstallerModuleEnabled(self, key)
  end
end

local function InstallerCompleted()
  local db = type(RUI.EnsureDB) == "function" and RUI:EnsureDB() or nil
  return db and db.installer and db.installer.initialCompleted == true
end

local function HideLegacyRootFrames()
  for _, definition in pairs(RUI.classRegistry or {}) do
    local frameName = type(definition) == "table" and definition.hudFrameName or nil
    local frame = frameName and _G[frameName] or nil
    if frame then
      if type(frame.Hide) == "function" then pcall(frame.Hide, frame) end
      if type(frame.SetAlpha) == "function" then pcall(frame.SetAlpha, frame, 0) end
      if type(frame.EnableMouse) == "function" then pcall(frame.EnableMouse, frame, false) end
    end
  end
end

local function StopLegacyHUD()
  local module = RUI.activeModule
  if module and type(module.deactivate) == "function" then pcall(module.deactivate, module) end
  RUI.activeModule = nil
  if type(RUI.DeactivatePrimaryPower) == "function" then pcall(RUI.DeactivatePrimaryPower, RUI) end
  if type(RUI.StopHUDVisibilityDriver) == "function" then pcall(RUI.StopHUDVisibilityDriver, RUI) end
  HideLegacyRootFrames()
end

local function TrackerOptions(className)
  local options = {
    size = 38,
    gap = 6,
    consumeMouse = false,
  }

  -- Mortal Form is the intentional inverse/fallback of Cursed Form. This is
  -- the only beta.20 fallback state; all other states require exact live class
  -- aura/form evidence from StateTracker.lua.
  if className == "Bloodmage" then
    options.fallbackState = {name = "Mortal Form"}
    options.alwaysFallback = true
  end
  return options
end

local function HideCurrentTracker()
  if currentTracker and type(currentTracker.Hide) == "function" then
    pcall(currentTracker.Hide, currentTracker)
  end
end

function RUI:RefreshBeta20StateLane(force)
  if not InstallerCompleted() then
    HideCurrentTracker()
    return false, "installer-not-complete"
  end
  if type(self.CreateClassStateTracker) ~= "function" then
    return false, "state-tracker-not-loaded"
  end
  if type(self.GetDetectedClass) ~= "function" then return false, "class-detection-unavailable" end

  local className = self:GetDetectedClass()
  if self.NormalizeClassName then className = self:NormalizeClassName(className) or className end
  if not className or className == "" then
    HideCurrentTracker()
    return false, "class-not-detected"
  end

  if force or className ~= currentClass or not currentTracker then
    HideCurrentTracker()
    currentClass = className
    currentTracker = self:CreateClassStateTracker(UIParent, className, TrackerOptions(className))
  end

  if not currentTracker then return false, "state-tracker-create-failed" end
  local ok, count = pcall(currentTracker.Update, currentTracker)
  if not ok then return false, tostring(count) end
  if type(self.ReflowClassStateTrackers) == "function" then pcall(self.ReflowClassStateTrackers, self) end
  return true, tonumber(count) or 0
end

-- Keep the public activation API compatible for old saved databases. In beta.20
-- this request no longer activates an ability HUD; it can only refresh the one
-- allowed native state lane.
function RUI:ActivateClassHUD(force)
  StopLegacyHUD()
  local ok, reason = self:RefreshBeta20StateLane(force == true)
  self.activeClass = type(self.GetDetectedClass) == "function" and self:GetDetectedClass() or nil
  return ok or reason == "installer-not-complete", "complete"
end

function RUI:DeactivateAllHUD()
  StopLegacyHUD()
  HideCurrentTracker()
  self.activeClass = nil
end

local function FinalizeModuleOwnership()
  -- The legacy module registry remains available for upgrade compatibility, but
  -- it is not an installer step and its renderer is never activated in beta.20.
  RUI.moduleOrder = {"elvui", "turboplates", "mobspells", "cvars", "fonts", "cleanup", "details"}

  local filtered = {}
  local hasWeakAuras = false
  for _, dependency in ipairs(RUI.installerDependencies or {}) do
    if dependency.key ~= "dbm" then
      filtered[#filtered + 1] = dependency
      if dependency.key == "weakauras" then hasWeakAuras = true end
    end
  end
  if not hasWeakAuras then
    filtered[#filtered + 1] = {key="weakauras", label="WeakAuras", names={"WeakAuras"}, required=true}
  end
  RUI.installerDependencies = filtered

  local turbo = RUI.moduleInstallers and RUI.moduleInstallers.turboplates
  if turbo then
    turbo.install = function(self) return self:InstallTurboPlatesProfile("1440p") end
    turbo.validate = function(self)
      local db = self:EnsureDB()
      local record = db.integrations and db.integrations.turboNaowhBeta20
      return type(TurboPlatesDB) == "table" and record and record.version == self.version,
        "Naowh TurboPlates beta.20 profile was not applied"
    end
  end
end

FinalizeModuleOwnership()

local function EnsureDriver()
  if stateDriver then return end
  stateDriver = CreateFrame("Frame", "RetreatUIBeta20StateLaneDriver", UIParent)
  for _, eventName in ipairs({
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UNIT_AURA",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "SPELLS_CHANGED",
    "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED",
    "ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED",
  }) do pcall(stateDriver.RegisterEvent, stateDriver, eventName) end

  stateDriver:SetScript("OnEvent", function(_, _, unit)
    if unit and unit ~= "player" then return end
    RUI:After(0, function() RUI:RefreshBeta20StateLane(false) end)
    RUI:After(0.12, function() RUI:RefreshBeta20StateLane(false) end)
  end)

  -- Only run while a displayed state has a real expiry timer. Permanent class
  -- states are entirely event-driven.
  stateDriver:SetScript("OnUpdate", function(_, elapsed)
    if not currentTracker or not currentTracker.HasTimers or not currentTracker:HasTimers() then
      stateTimerElapsed = 0
      return
    end
    stateTimerElapsed = stateTimerElapsed + elapsed
    if stateTimerElapsed < 0.10 then return end
    stateTimerElapsed = 0
    if currentTracker.UpdateTimers then currentTracker:UpdateTimers() end
  end)
end

local loadDriver = CreateFrame("Frame", "RetreatUIBeta20HUDOwnershipLoader")
loadDriver:RegisterEvent("ADDON_LOADED")
loadDriver:SetScript("OnEvent", function(self, _, addonName)
  if addonName ~= "RetreatUI_Classes" then return end
  EnsureDriver()
  StopLegacyHUD()
  RUI:After(0, function() RUI:RefreshBeta20StateLane(true) end)
  self:UnregisterEvent("ADDON_LOADED")
end)

if IsAddOnLoaded and IsAddOnLoaded("RetreatUI_Classes") then
  EnsureDriver()
  StopLegacyHUD()
end

RUI._beta20HUDOwnershipLoaded = true
RUI._beta20HUDOwnershipRevision = 20
