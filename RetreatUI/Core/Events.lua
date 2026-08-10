local RUI = RetreatUI
local events = CreateFrame("Frame")
local autoScheduled = false
local runtimeApplied = false
local hudRefreshSerial = 0
local playerLoggedIn = false
local firstWorldEntry = true
local deferredCombatReason
local refreshPassState = {}

local HUD_REFRESH_EVENTS = {
  SPELLS_CHANGED = true,
  PLAYER_TALENT_UPDATE = true,
  CHARACTER_POINTS_CHANGED = true,
  ACTIVE_TALENT_GROUP_CHANGED = true,
  LEARNED_SPELL_IN_TAB = true,
  PLAYER_LEVEL_UP = true,
  ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED = true,
  ASCENSION_KNOWN_ENTRIES_UPDATED = true,
}

-- These events can alter the selected build even when the spellbook signature
-- remains identical, so the build fingerprint still needs one cached check.
local PROFILE_CHECK_EVENTS = {
  PLAYER_TALENT_UPDATE = true,
  CHARACTER_POINTS_CHANGED = true,
  ACTIVE_TALENT_GROUP_CHANGED = true,
  ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED = true,
  ASCENSION_KNOWN_ENTRIES_UPDATED = true,
}

-- Ascension may populate replacement spell IDs shortly after the first event.
-- One quiet settlement scan is enough; the old system performed four complete
-- passes here and another four in BuildProfiles.
local SETTLEMENT_EVENTS = {
  SPELLS_CHANGED = true,
  PLAYER_TALENT_UPDATE = true,
  CHARACTER_POINTS_CHANGED = true,
  ACTIVE_TALENT_GROUP_CHANGED = true,
  LEARNED_SPELL_IN_TAB = true,
  PLAYER_LEVEL_UP = true,
  ASCENSION_CA_SPECIALIZATION_ACTIVE_ID_CHANGED = true,
  ASCENSION_KNOWN_ENTRIES_UPDATED = true,
}

RUI.performanceRefreshStats = RUI.performanceRefreshStats or {
  scheduled = 0,
  executed = 0,
  deferred = 0,
  hudRebuilds = 0,
}
local performanceStats = RUI.performanceRefreshStats

local function IsInCombat()
  if type(InCombatLockdown) ~= "function" then return false end
  local ok, locked = pcall(InCombatLockdown)
  return ok and locked == true
end

local function IsSupported()
  return type(RUI.IsSupportedCharacter) == "function" and RUI:IsSupportedCharacter()
end

local function ModuleEnabled(key)
  return type(RUI.IsInstallerModuleEnabled) ~= "function" or RUI:IsInstallerModuleEnabled(key)
end

local function InstallerCompleted()
  local db = type(RUI.EnsureDB) == "function" and RUI:EnsureDB() or nil
  return db and db.installer and db.installer.initialCompleted == true
end

local function DisableClassHUD()
  if type(RUI.DeactivateAllHUD) == "function" then RUI:DeactivateAllHUD() end
end

local function ScheduleInstaller()
  if autoScheduled or InstallerCompleted() then return end
  autoScheduled = true
  RUI:After(1.0, function()
    autoScheduled = false
    if InstallerCompleted() then return end
    if type(RUI.ShowInstaller) == "function" then
      local ok, err = pcall(RUI.ShowInstaller, RUI, false)
      if not ok then RUI:Print("Installer startup failed: " .. tostring(err)) end
    else
      RUI:Print("Installer module did not load. Reload the UI and try /rui install.")
    end
  end)
end

local function ClassHUDSelectedAndReady()
  if not ModuleEnabled("classHUD") or not IsSupported() then return false end
  local detectedClass = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
  local installed = type(RUI.IsClassInstallCompleted) == "function" and RUI:IsClassInstallCompleted(detectedClass)
  return installed == true, detectedClass
end

local function ScanSpellbook(force)
  if type(RUI.ScanSpellbook) ~= "function" then return true end
  local ok, _, changed = pcall(RUI.ScanSpellbook, RUI, force == true)
  if not ok then
    RUI:Print("Spellbook refresh failed: " .. tostring(_))
    return false
  end
  return changed == true
end

local function RefreshBuildProfile(reason)
  if type(RUI.RefreshBuildProfile) ~= "function" then return false end
  local ok, changed = pcall(RUI.RefreshBuildProfile, RUI, reason, false, true)
  if not ok then
    RUI:Print("Build profile refresh failed after " .. tostring(reason) .. ": " .. tostring(changed))
    return false
  end
  return changed == true
end

local function RefreshInstalledHUD(reason, serial, settlement)
  if serial ~= hudRefreshSerial then return end
  local passState = refreshPassState[serial]
  if not passState then return end

  if IsInCombat() then
    deferredCombatReason = reason
    performanceStats.deferred = (tonumber(performanceStats.deferred) or 0) + 1
    return
  end

  performanceStats.executed = (tonumber(performanceStats.executed) or 0) + 1
  local spellbookChanged = ScanSpellbook(settlement == true)
  local profileChanged = false
  if spellbookChanged or (not settlement and PROFILE_CHECK_EVENTS[reason]) then
    profileChanged = RefreshBuildProfile(reason)
  end

  if settlement then refreshPassState[serial] = nil end
  if not spellbookChanged and not profileChanged then return end

  local ready, detectedClass = ClassHUDSelectedAndReady()
  if not ready then DisableClassHUD(); return end
  if type(RUI.InvalidateRacialCache) == "function" then RUI:InvalidateRacialCache() end

  if type(RUI.ActivateClassHUD) == "function" then
    local ok, activated, mode = pcall(RUI.ActivateClassHUD, RUI, true)
    if not ok then
      RUI:Print("HUD refresh failed after " .. tostring(reason) .. ": " .. tostring(activated))
      return
    end
    if activated then
      performanceStats.hudRebuilds = (tonumber(performanceStats.hudRebuilds) or 0) + 1
      if type(RUI.SetModuleStatus) == "function" and not settlement then
        RUI:SetModuleStatus("classHUD", "success", tostring(detectedClass or "Class") .. " HUD refreshed")
      end
    elseif not settlement then
      RUI:Print(tostring(detectedClass or "Class") .. " HUD could not refresh (" .. tostring(mode or "unknown") .. ").")
    end
  end
end

function RUI:ScheduleHUDRefresh(reason)
  if not ModuleEnabled("classHUD") then return false end
  reason = tostring(reason or "HUD_REFRESH")

  if IsInCombat() then
    deferredCombatReason = reason
    performanceStats.deferred = (tonumber(performanceStats.deferred) or 0) + 1
    return true
  end

  hudRefreshSerial = hudRefreshSerial + 1
  local serial = hudRefreshSerial
  refreshPassState[serial] = {reason=reason}
  performanceStats.scheduled = (tonumber(performanceStats.scheduled) or 0) + 1

  -- Event bursts collapse into this single primary refresh. Older callbacks see
  -- a stale serial and exit before scanning the spellbook or rebuilding rows.
  self:After(0.18, function()
    RefreshInstalledHUD(reason, serial, false)
    if not SETTLEMENT_EVENTS[reason] then refreshPassState[serial] = nil end
  end)

  if SETTLEMENT_EVENTS[reason] then
    self:After(0.95, function()
      RefreshInstalledHUD(reason, serial, true)
    end)
  end
  return true
end

local function ApplyRuntimeOnce()
  if runtimeApplied then return end
  runtimeApplied = true

  if ModuleEnabled("cleanup") and type(RUI.ApplyHiddenFrames) == "function" then
    RUI:After(0.20, function() RUI:ApplyHiddenFrames() end)
  end
  if ModuleEnabled("gameSettings") and type(RUI.ApplyCombatTextStyle) == "function" then
    RUI:After(0.40, function() RUI:ApplyCombatTextStyle() end)
  end
  if ModuleEnabled("classHUD") and IsSupported() and type(RUI.InitializeTotemBarMover) == "function" then
    RUI:After(0.55, function() RUI:InitializeTotemBarMover() end)
    RUI:After(1.50, function() RUI:InitializeTotemBarMover() end)
  end
  if ModuleEnabled("nameplates") and type(RUI.InitializeTurboManaColoring) == "function" then
    RUI:After(0.65, function() RUI:InitializeTurboManaColoring() end)
  end
  if ModuleEnabled("partyTrackers") and type(RUI.InitializePartyUtilityTracker) == "function" then
    RUI:After(0.72, function() RUI:InitializePartyUtilityTracker() end)
  end
  if ModuleEnabled("trinketHUD") and type(RUI.InitializeTrinketTracker) == "function" then
    RUI:After(0.78, function() RUI:InitializeTrinketTracker() end)
  end
  if ModuleEnabled("npcTracking") and type(RUI.RefreshNPCSpellCooldowns) == "function" then
    RUI:After(0.82, function() RUI:RefreshNPCSpellCooldowns() end)
  end
  if ModuleEnabled("unitframes") and type(RUI.ApplyElvUIHUDPolish) == "function" then
    RUI:After(0.45, function() RUI:ApplyElvUIHUDPolish(false) end)
  end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
for eventName in pairs(HUD_REFRESH_EVENTS) do pcall(events.RegisterEvent, events, eventName) end

events:SetScript("OnEvent", function(_, event, addonName)
  if HUD_REFRESH_EVENTS[event] then
    if playerLoggedIn then RUI:ScheduleHUDRefresh(event) end
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    local reason = deferredCombatReason
    deferredCombatReason = nil
    if reason then RUI:ScheduleHUDRefresh(reason) end
    return
  end

  if event == "ADDON_LOADED" then
    if addonName == "RetreatUI" or addonName == "RetreatUI_Classes" then RUI:EnsureDB() end
    return
  end

  if event == "PLAYER_LOGIN" then
    playerLoggedIn = true
    ScanSpellbook(true)
    if type(RUI.RefreshBuildProfile) == "function" then
      local ok, err = pcall(RUI.RefreshBuildProfile, RUI, "PLAYER_LOGIN", true, true)
      if not ok then RUI:Print("Initial build profile failed: " .. tostring(err)) end
    end
    if type(RUI.HandleVersionLogin) == "function" then
      local ok, err = pcall(RUI.HandleVersionLogin, RUI)
      if not ok then RUI:Print("Version notification failed: " .. tostring(err)) end
    end
    if ModuleEnabled("nameplates") and type(RUI.DisableElvUINamePlates) == "function" then RUI:DisableElvUINamePlates() end
    ScheduleInstaller()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    local spellbookChanged = ScanSpellbook(false)
    if spellbookChanged or not RUI._currentBuildState then RefreshBuildProfile("PLAYER_ENTERING_WORLD") end

    local ready, detectedClass = ClassHUDSelectedAndReady()
    if ready then
      if not RUI.activeModule or RUI.activeClass ~= detectedClass then
        local activated, mode = RUI:ActivateClassHUD()
        if activated and type(RUI.SetModuleStatus) == "function" then
          RUI:SetModuleStatus("classHUD", "success", tostring(detectedClass or "Class") .. " HUD activated")
        elseif not activated then
          RUI:Print(tostring(detectedClass or "Class") .. " HUD could not be activated (" .. tostring(mode or "unknown") .. ").")
        end
      end
    else
      DisableClassHUD()
    end

    ApplyRuntimeOnce()
    ScheduleInstaller()

    -- One delayed first-login settlement replaces the former pair of complete
    -- scans and forced HUD activations on every world transition.
    if firstWorldEntry and ModuleEnabled("classHUD") then
      firstWorldEntry = false
      RUI:After(0.75, function() RUI:ScheduleHUDRefresh("PLAYER_ENTERING_WORLD_SETTLE") end)
    end
  end
end)
