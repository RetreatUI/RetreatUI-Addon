local RUI = RetreatUI
local events = CreateFrame("Frame")
local autoScheduled = false
local runtimeApplied = false

local function IsSupported()
  return type(RUI.IsSupportedCharacter) == "function" and RUI:IsSupportedCharacter()
end

local function DisableUnsupportedUI()
  if type(RUI.DeactivateAllHUD) == "function" then RUI:DeactivateAllHUD() end
  if type(RUI.HideInstaller) == "function" then RUI:HideInstaller() end
end

local function ScheduleInstaller()
  if autoScheduled or not IsSupported() then return end
  local db = RUI:EnsureDB()
  local hasCompletedInitialInstall = db.installer.initialCompleted == true
    or (db.installer.completedVersion and db.installer.completedVersion ~= "")
  if hasCompletedInitialInstall then return end

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
      RUI:Print("Installer module did not load. Use /rui report.")
    end
  end)
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

  local elvuiStatus = RUI:GetModuleStatus("elvui")
  if elvuiStatus and elvuiStatus.ok and type(RUI.RemoveRightLootTradeChat) == "function" then
    RUI:After(0.50, function()
      if IsSupported() then RUI:RemoveRightLootTradeChat() end
    end)
  end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event, addonName)
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
    -- Force a fresh scan now that the Ascension spellbook is fully available.
    if type(RUI.ScanSpellbook) == "function" then RUI:ScanSpellbook() end

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
    if not IsSupported() then
      DisableUnsupportedUI()
      return
    end

    local hud = RUI:GetModuleStatus("classHUD")
    if hud and hud.ok and not RUI.activeModule then RUI:ActivateClassHUD() end
    ApplyRuntimeOnce()
    ScheduleInstaller()
  end
end)
