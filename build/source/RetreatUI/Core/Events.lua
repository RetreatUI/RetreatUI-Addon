local RUI = RetreatUI
local events = CreateFrame("Frame")
local autoScheduled = false
local runtimeApplied = false
local hudRefreshSerial = 0
local playerLoggedIn = false

-- Ascension does not consistently emit the stock WotLK talent events when a
-- Character Advancement specialization is changed. Keep one global refresh
-- path for every RetreatUI class HUD so all modules rebuild from the actual
-- learned spellbook instead of remaining on the layout that was active at
-- login.
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

local function DisableUnsupportedUI()
  if type(RUI.DeactivateAllHUD) == "function" then RUI:DeactivateAllHUD() end
  if type(RUI.HideInstaller) == "function" then RUI:HideInstaller() end
end

local function ScheduleInstaller()
  if autoScheduled or not IsSupported() then return end
  if type(RUI.IsClassInstallCompleted) == "function" and RUI:IsClassInstallCompleted() then return end

  autoScheduled = true
  RUI:After(1.0, function()
    autoScheduled = false
    if not IsSupported() then
      DisableUnsupportedUI()
      return
    end
    if type(RUI.ShowInstaller) == "function" then
      local ok, err = pcall(RUI.ShowInstaller, RUI, false)
      if not ok then RUI:Print("Installer startup failed: " .. tostring(err)) end
    else
      RUI:Print("Installer module did not load. Reload the UI and try /rui install.")
    end
  end)
end

local function RefreshInstalledHUD(reason, serial, pass)
  if serial ~= hudRefreshSerial then return end
  local changed = true
  if type(RUI.ScanSpellbook) == "function" then
    local _, scanChanged = RUI:ScanSpellbook()
    changed = scanChanged == true
  end
  if type(RUI.RefreshBuildProfile) == "function" then
    RUI:RefreshBuildProfile(reason, false)
  end

  -- Stock SPELLS_CHANGED is noisy (opening the spellbook can fire it). Only
  -- rebuild for that event when the learned spell signature actually changed.
  -- Talent/spec events force the first pass, then later passes rebuild only if
  -- the replacement spellbook arrives asynchronously.
  local forceThisPass = reason ~= "SPELLS_CHANGED" and pass == 1
  if not changed and not forceThisPass then return end

  if not IsSupported() then
    DisableUnsupportedUI()
    return
  end

  local detectedClass = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
  local classInstalled = type(RUI.IsClassInstallCompleted) == "function" and RUI:IsClassInstallCompleted(detectedClass)
  if not classInstalled then return end

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

  if pass == 1 and type(RUI.ScheduleFrameCleanupPasses) == "function" then
    RUI:ScheduleFrameCleanupPasses(true)
  end
end

local function ScheduleHUDRefresh(reason)
  hudRefreshSerial = hudRefreshSerial + 1
  local serial = hudRefreshSerial

  -- The CA event can fire before the replacement specialization spells have
  -- reached the spellbook. Re-scan a few times, but cancel older batches as
  -- soon as a newer build-change event arrives.
  for pass, delay in ipairs({0.05, 0.30, 0.80, 1.60}) do
    RUI:After(delay, function()
      RefreshInstalledHUD(reason, serial, pass)
    end)
  end
end

local function ApplyRuntimeOnce()
  if runtimeApplied then return end
  runtimeApplied = true

  -- Profile and mover settings are persistent. Earlier versions rebuilt ElvUI
  -- several times on every login; the installer now owns profile application,
  -- while runtime startup only enables the lightweight systems that need it.
  if type(RUI.ApplyHiddenFrames) == "function" then
    RUI:After(0.20, function()
      if IsSupported() then RUI:ApplyHiddenFrames() end
    end)
  end

  if type(RUI.ApplyCombatTextStyle) == "function" then
    RUI:After(0.40, function()
      if IsSupported() then RUI:ApplyCombatTextStyle() end
    end)
  end

  if type(RUI.InitializeTotemBarMover) == "function" then
    RUI:After(0.55, function()
      if IsSupported() then RUI:InitializeTotemBarMover() end
    end)
    RUI:After(1.50, function()
      if IsSupported() then RUI:InitializeTotemBarMover() end
    end)
  end

  if type(RUI.InitializeTurboManaColoring) == "function" then
    RUI:After(0.65, function()
      if IsSupported() then RUI:InitializeTurboManaColoring() end
    end)
  end

  if type(RUI.InitializePartyUtilityTracker) == "function" then
    RUI:After(0.72, function()
      if IsSupported() then RUI:InitializePartyUtilityTracker() end
    end)
  end

  if type(RUI.InitializeTrinketTracker) == "function" then
    RUI:After(0.78, function()
      if IsSupported() then RUI:InitializeTrinketTracker() end
    end)
  end


  -- Refresh only RetreatUI's lightweight ElvUI unitframe settings on login.
  -- This clears Ascension classbar/power percentage text such as the stray
  -- Necromancer "100%" without requiring the installer or resetting movers.
  if type(RUI.ApplyElvUIHUDPolish) == "function"
    and (type(RUI.IsInstallerModuleEnabled) ~= "function" or RUI:IsInstallerModuleEnabled("elvui")) then
    RUI:After(0.45, function()
      if IsSupported() then RUI:ApplyElvUIHUDPolish(false) end
    end)
  end

  -- Close only the unwanted Loot/Trade chat windows. The right chat panel
  -- and its data-text strip are intentionally preserved.
  local elvuiStatus = RUI:GetModuleStatus("elvui")
  local elvuiEnabled = type(RUI.IsInstallerModuleEnabled) ~= "function" or RUI:IsInstallerModuleEnabled("elvui")
  if elvuiEnabled and elvuiStatus and elvuiStatus.ok and type(RUI.RemoveRightLootTradeChat) == "function" then
    RUI:After(0.50, function()
      if IsSupported() then RUI:RemoveRightLootTradeChat() end
    end)
  end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
for eventName in pairs(HUD_REFRESH_EVENTS) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, event, addonName)
  if HUD_REFRESH_EVENTS[event] then
    if playerLoggedIn then ScheduleHUDRefresh(event) end
    return
  end
  if event == "ADDON_LOADED" then
    if addonName == "RetreatUI" or addonName == "RetreatUI_Classes" then
      RUI:EnsureDB()
      -- Do not scan the spellbook during addon loading. Some Ascension client
      -- builds expose a base class through UnitClass and populate the CoA
      -- spellbook only at PLAYER_LOGIN; caching an early empty scan would make
      -- the correct class appear unsupported for the rest of the session.
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    playerLoggedIn = true
    -- Force a fresh scan now that the Ascension spellbook is fully available.
    if type(RUI.ScanSpellbook) == "function" then RUI:ScanSpellbook() end
    if type(RUI.RefreshBuildProfile) == "function" then RUI:RefreshBuildProfile("PLAYER_LOGIN", true) end

    if type(RUI.HandleVersionLogin) == "function" then
      local ok, err = pcall(RUI.HandleVersionLogin, RUI)
      if not ok then RUI:Print("Version notification failed: " .. tostring(err)) end
    end

    if not IsSupported() then
      DisableUnsupportedUI()
      return
    end
    if type(RUI.DisableElvUINamePlates) == "function" then
      RUI:DisableElvUINamePlates()
    end
    ScheduleInstaller()
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    -- Ascension can finish populating the CoA spellbook and custom class state
    -- after PLAYER_LOGIN. Rescan here so reloads do not lose the active class,
    -- primary resource bar or class-resource tracker.
    if type(RUI.ScanSpellbook) == "function" then RUI:ScanSpellbook() end
    if type(RUI.RefreshBuildProfile) == "function" then RUI:RefreshBuildProfile("PLAYER_ENTERING_WORLD", false) end

    if not IsSupported() then
      DisableUnsupportedUI()
      return
    end

    local detectedClass = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
    local classInstalled = type(RUI.IsClassInstallCompleted) == "function" and RUI:IsClassInstallCompleted(detectedClass)

    -- A class HUD is activated only after that class has completed the installer.
    -- Fresh characters therefore open directly into their own class-themed setup
    -- instead of inheriting a globally preinstalled baseline HUD.
    if not classInstalled then
      if type(RUI.DeactivateAllHUD) == "function" then RUI:DeactivateAllHUD() end
      ScheduleInstaller()
      return
    end

    if not RUI.activeModule or RUI.activeClass ~= detectedClass then
      local activated, mode = RUI:ActivateClassHUD()
      if activated and type(RUI.SetModuleStatus) == "function" then
        RUI:SetModuleStatus("classHUD", "success", tostring(detectedClass or "Class") .. " HUD activated")
      elseif not activated then
        RUI:Print(tostring(detectedClass or "Class") .. " HUD could not be activated (" .. tostring(mode or "unknown") .. ").")
      end
    end
    ApplyRuntimeOnce()

    -- A few Ascension resources and spellbook markers are created a fraction
    -- of a second after entering the world. Re-detect and re-activate the same
    -- installed class in place instead of requiring /rui reset or /rui repair.
    for _, delay in ipairs({0.25, 1.00}) do
      RUI:After(delay, function()
        if type(RUI.ScanSpellbook) == "function" then RUI:ScanSpellbook() end
        if not IsSupported() then return end
        local delayedClass = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
        local delayedInstalled = type(RUI.IsClassInstallCompleted) == "function" and RUI:IsClassInstallCompleted(delayedClass)
        if delayedInstalled and type(RUI.ActivateClassHUD) == "function" then
          RUI:ActivateClassHUD(true)
        end
      end)
    end
  end
end)
