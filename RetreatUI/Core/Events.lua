local RUI = RetreatUI
local events = CreateFrame("Frame")
local autoScheduled = false
local runtimeApplied = false
local hudRefreshSerial = 0
local playerLoggedIn = false

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

local function RefreshInstalledHUD(reason, serial, pass)
  if serial ~= hudRefreshSerial then return end
  local changed = true
  if type(RUI.ScanSpellbook) == "function" then
    local _, scanChanged = RUI:ScanSpellbook()
    changed = scanChanged == true
  end
  if type(RUI.RefreshBuildProfile) == "function" then RUI:RefreshBuildProfile(reason, false) end
  local forceThisPass = reason ~= "SPELLS_CHANGED" and pass == 1
  if not changed and not forceThisPass then return end

  local ready, detectedClass = ClassHUDSelectedAndReady()
  if not ready then DisableClassHUD(); return end
  if type(RUI.InvalidateRacialCache) == "function" then RUI:InvalidateRacialCache() end
  if type(RUI.ActivateClassHUD) == "function" then
    local ok, activated, mode = pcall(RUI.ActivateClassHUD, RUI, true)
    if not ok then
      RUI:Print("HUD refresh failed after " .. tostring(reason) .. ": " .. tostring(activated))
      return
    end
    if activated and type(RUI.SetModuleStatus) == "function" and pass == 1 then
      RUI:SetModuleStatus("classHUD", "success", tostring(detectedClass or "Class") .. " HUD refreshed")
    elseif not activated and pass == 1 then
      RUI:Print(tostring(detectedClass or "Class") .. " HUD could not refresh (" .. tostring(mode or "unknown") .. ").")
    end
  end
end

local function ScheduleHUDRefresh(reason)
  if not ModuleEnabled("classHUD") then return end
  hudRefreshSerial = hudRefreshSerial + 1
  local serial = hudRefreshSerial
  for pass, delay in ipairs({0.05, 0.30, 0.80, 1.60}) do
    RUI:After(delay, function() RefreshInstalledHUD(reason, serial, pass) end)
  end
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
  local unitframeStatus = RUI:GetModuleStatus("unitframes")
  if ModuleEnabled("unitframes") and unitframeStatus and unitframeStatus.ok and type(RUI.RemoveRightLootTradeChat) == "function" then
    RUI:After(0.50, function() RUI:RemoveRightLootTradeChat() end)
  end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
for eventName in pairs(HUD_REFRESH_EVENTS) do pcall(events.RegisterEvent, events, eventName) end

events:SetScript("OnEvent", function(_, event, addonName)
  if HUD_REFRESH_EVENTS[event] then
    if playerLoggedIn then ScheduleHUDRefresh(event) end
    return
  end

  if event == "ADDON_LOADED" then
    if addonName == "RetreatUI" or addonName == "RetreatUI_Classes" then RUI:EnsureDB() end
    return
  end

  if event == "PLAYER_LOGIN" then
    playerLoggedIn = true
    if type(RUI.ScanSpellbook) == "function" then RUI:ScanSpellbook() end
    if type(RUI.RefreshBuildProfile) == "function" then RUI:RefreshBuildProfile("PLAYER_LOGIN", true) end
    if type(RUI.HandleVersionLogin) == "function" then
      local ok, err = pcall(RUI.HandleVersionLogin, RUI)
      if not ok then RUI:Print("Version notification failed: " .. tostring(err)) end
    end
    if ModuleEnabled("nameplates") and type(RUI.DisableElvUINamePlates) == "function" then RUI:DisableElvUINamePlates() end
    ScheduleInstaller()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    if type(RUI.ScanSpellbook) == "function" then RUI:ScanSpellbook() end
    if type(RUI.RefreshBuildProfile) == "function" then RUI:RefreshBuildProfile("PLAYER_ENTERING_WORLD", false) end

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

    if ModuleEnabled("classHUD") then
      for _, delay in ipairs({0.25, 1.00}) do
        RUI:After(delay, function()
          if type(RUI.ScanSpellbook) == "function" then RUI:ScanSpellbook() end
          local delayedReady = ClassHUDSelectedAndReady()
          if delayedReady and type(RUI.ActivateClassHUD) == "function" then RUI:ActivateClassHUD(true) end
        end)
      end
    end
  end
end)
