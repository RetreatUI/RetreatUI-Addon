RetreatUI = RetreatUI or {}
local RUI = RetreatUI

RUI.name = "RetreatUI"
RUI.version = (GetAddOnMetadata and GetAddOnMetadata("RetreatUI", "Version")) or "1.0.8"
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
    {"Castbars and action bars", "ApplyElvUIHUDPolish", true},
    {"Target aura bars", "RefreshTargetAuraBars"},
    {"Combat text", "ApplyCombatTextStyle"},
    {"TurboPlates", "ApplyTurboPlatesRuntime"},
    {"NPC cooldowns", "RefreshNPCSpellCooldowns"},
    {"Right chat cleanup", "RemoveRightLootTradeChat", nil, true},
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
  local installed = false
  if type(RUI.EnsureDB) == "function" then
    local db = RUI:EnsureDB()
    installed = db.installer and db.installer.completedVersion == RUI.version
  end
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

  if command == "status" or command == "version" then ShowStatus(); return end
  if command == "changelog" and type(RUI.ShowChangelog) == "function" then
    local ok, err = pcall(RUI.ShowChangelog, RUI)
    if not ok then Chat("The changelog could not open: " .. tostring(err)) end
    return
  end
  if command == "repair" then RunRepair(); return end

  if command == "reset" and type(RUI.EnsureDB) == "function" then
    if not RequireSupportedClass() then return end
    local db = RUI:EnsureDB()
    db.installer.completedVersion = nil
    db.installer.initialCompleted = nil
    db.moduleStatus = {}
    if type(RUI.ShowInstaller) == "function" then RUI:ShowInstaller(true) end
    return
  end

  Chat("Commands: /rui | /rui status | /rui changelog | /rui repair | /rui reset")
end
