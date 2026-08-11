RetreatUI = RetreatUI or {}
local RUI = RetreatUI

RUI.name = "RetreatUI"
RUI.version = (GetAddOnMetadata and GetAddOnMetadata("RetreatUI", "Version")) or "1.1.0-beta.14"
RUI._loaderLoaded = true

local function Chat(message)
  local text = "|cffff5a1fRetreatUI:|r " .. tostring(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  elseif print then
    print(text)
  end
end

RUI.BootstrapPrint = Chat

local function IsSupported()
  return type(RUI.IsSupportedCharacter) == "function" and RUI:IsSupportedCharacter()
end

local function RequireSupportedClass()
  if IsSupported() then return true end
  if type(RUI.HideInstaller) == "function" then RUI:HideInstaller() end
  Chat(type(RUI.GetUnsupportedMessage) == "function"
    and RUI:GetUnsupportedMessage()
    or "No supported RetreatUI class module is active on this character.")
  return false
end

local function RunRepair()
  if not RequireSupportedClass() then return false end
  local repaired, failed = 0, {}
  local actions = {
    {"Class HUD", "ActivateClassHUD", true},
    {"Frame cleanup", "RunFrameCleanupNow"},
    {"Party frame", "ApplyPartyFramePosition", false},
    {"Target of Target", "ApplyTargetTargetFrame", false},
    {"ElvUI aura settings", "RepairElvUIAuraProfiles", true},
    {"Castbars and action bars", "ApplyElvUIHUDPolish", true},
    {"Target aura bars", "RefreshTargetAuraBars"},
    {"Combat text", "ApplyCombatTextStyle"},
    {"TurboPlates", "ApplyTurboPlatesRuntime"},
    {"NPC cooldowns", "RefreshNPCSpellCooldowns"},
    {"Party Utility", "RefreshPartyUtility"},
  }

  for _, action in ipairs(actions) do
    local label, method, argument, allowFalse = action[1], action[2], action[3], action[4]
    local fn = RUI[method]
    if type(fn) == "function" then
      local ok, result = pcall(fn, RUI, argument)
      if ok and (result ~= false or allowFalse) then
        repaired = repaired + 1
      else
        failed[#failed + 1] = label
      end
    end
  end

  if #failed > 0 then
    Chat("Repair finished: " .. repaired .. " systems refreshed. Failed: " .. table.concat(failed, ", ") .. ".")
  else
    Chat("Repair finished: " .. repaired .. " systems refreshed.")
  end
  return #failed == 0
end

local function ShowStatus()
  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or "not detected"
  local installed = type(RUI.IsClassInstallCompleted) == "function" and RUI:IsClassInstallCompleted(className) or false
  Chat("Core " .. tostring(RUI.version)
    .. " | Classes " .. tostring(RUI.classesVersion or "not loaded")
    .. " | class: " .. tostring(className)
    .. " | supported: " .. tostring(IsSupported())
    .. " | installed: " .. tostring(installed))
end


_G["SLASH_RETREATUI1"] = "/rui"
_G["SLASH_RETREATUI2"] = "/retreatui"
SlashCmdList = SlashCmdList or {}
SlashCmdList["RETREATUI"] = function(message)
  local command = string.lower((message or ""):match("^%s*(.-)%s*$"))

  if command == "" or command == "install" then
    if not RequireSupportedClass() then return end
    if type(RUI.ShowInstaller) ~= "function" then
      Chat("The installer did not finish loading. Reload the UI and try again.")
      return
    end
    local ok, err = pcall(RUI.ShowInstaller, RUI, true)
    if not ok then Chat("The installer could not open: " .. tostring(err)) end
    return
  end

  if command == "automation" or command == "auto" then
    local automation = RUI.AutoRoleCheck
    if automation and type(automation.OpenOptions) == "function" then
      local ok, opened = pcall(automation.OpenOptions, automation)
      if not ok or opened == false then Chat("The automation settings could not open.") end
    else
      Chat("The automation settings did not finish loading. Reload the UI and try again.")
    end
    return
  end


  if command == "hud" or command == "editor" then
    if not RequireSupportedClass() then return end
    if type(RUI.ToggleHUDEditor) == "function" then
      local ok, opened = pcall(RUI.ToggleHUDEditor, RUI)
      if not ok or opened == false then Chat("The HUD Editor could not open.") end
    else
      Chat("The HUD Editor did not finish loading. Reload the UI and try again.")
    end
    return
  end

  if command == "build" or command == "profile" then
    if not RequireSupportedClass() then return end
    if type(RUI.GetBuildProfileStatus) == "function" then
      local className, key, count = RUI:GetBuildProfileStatus()
      Chat(tostring(className) .. " | build profile " .. tostring(key) .. " | saved profiles: " .. tostring(count))
    else
      Chat("Build profile detection did not finish loading.")
    end
    return
  end


  if command == "utility" or command == "partyutility" then
    if not RequireSupportedClass() then return end
    if type(RUI.OpenPartyUtilitySettings) == "function" then
      local ok, opened = pcall(RUI.OpenPartyUtilitySettings, RUI)
      if not ok or opened == false then Chat("The Party Utility settings could not open.") end
    else
      Chat("Party Utility did not finish loading. Reload the UI and try again.")
    end
    return
  end

  if command == "utility test" or command == "partyutility test" then
    if type(RUI.TogglePartyUtilityPreview) == "function" then
      local ok, shown = pcall(RUI.TogglePartyUtilityPreview, RUI)
      if ok then Chat("Party Utility preview: " .. tostring(shown and "shown" or "hidden"))
      else Chat("Party Utility preview could not be changed.") end
    end
    return
  end


  if command == "buffs" or command == "buffmanager" then
    if type(RUI.ToggleBuffAssignmentManager) == "function" then
      local ok = pcall(RUI.ToggleBuffAssignmentManager, RUI)
      if not ok then Chat("The Buff Manager could not open.") end
    else
      Chat("The Buff Manager did not finish loading. Reload the UI and try again.")
    end
    return
  end

  if command == "buffs keybinds" or command == "buff keybinds" or command == "keybinds" then
    if type(RUI.ToggleBuffKeybindManager) == "function" then
      local ok = pcall(RUI.ToggleBuffKeybindManager, RUI)
      if not ok then Chat("The Buff Manager keybinds could not open.") end
    else
      Chat("The Buff Manager keybinds did not finish loading. Reload the UI and try again.")
    end
    return
  end

  if command == "status" or command == "version" then ShowStatus(); return end
  if command == "changelog" and type(RUI.ShowChangelog) == "function" then
    local ok, err = pcall(RUI.ShowChangelog, RUI)
    if not ok then Chat("The changelog could not open: " .. tostring(err)) end
    return
  end
  if command == "repair" then RunRepair(); return end

  if command == "reset" and type(RUI.EnsureDB) == "function" then
    if not RequireSupportedClass() then return end
    if type(RUI.ResetClassInstallation) == "function" then RUI:ResetClassInstallation() end
    if type(RUI.DeactivateAllHUD) == "function" then RUI:DeactivateAllHUD() end
    if type(RUI.ShowInstaller) == "function" then RUI:ShowInstaller(true) end
    return
  end

  Chat("Commands: /rui | /rui hud | /rui build | /rui utility | /rui buffs | /rui keybinds | /rui automation | /rui status | /rui changelog | /rui repair | /rui reset")
end
