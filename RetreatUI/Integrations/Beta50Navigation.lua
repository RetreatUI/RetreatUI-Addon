local RUI = RetreatUI
if not RUI then return end

local function Chat(message)
  local text = "|cffff5a1fRetreatUI:|r " .. tostring(message)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(text)
  elseif print then print(text) end
end

SlashCmdList = SlashCmdList or {}
SLASH_RETREATUI1 = "/rui"
SLASH_RETREATUI2 = "/retreatui"
SlashCmdList.RETREATUI = function(message)
  local command = string.lower((message or ""):match("^%s*(.-)%s*$"))

  if command == "" or command == "install" or command == "profile" or command == "profiles" then
    if type(RUI.OpenRetreatUI) == "function" then RUI:OpenRetreatUI("profiles") end
    return
  end
  if command == "hud" or command == "tracker" or command == "trackers" or command == "builder" or command == "editor" then
    if type(RUI.OpenRetreatUI) == "function" then RUI:OpenRetreatUI("hud") end
    return
  end
  if command == "unlock" or command == "move" then
    if type(RUI.ToggleHUDBarUnlockMode) == "function" then
      local ok, msg = RUI:ToggleHUDBarUnlockMode()
      if msg then Chat(msg) end
      if ok == false then return end
    end
    return
  end
  if command == "settings" then
    if type(RUI.OpenRetreatUI) == "function" then RUI:OpenRetreatUI("settings") end
    return
  end
  if command == "buffs" or command == "buffmanager" then
    if type(RUI.ToggleBuffAssignmentManager) == "function" then RUI:ToggleBuffAssignmentManager()
    else Chat("Buff Manager is a separate optional RetreatUI addon.") end
    return
  end
  if command == "status" or command == "version" then
    local style = type(RUI.GetRetreatStyleInfo) == "function" and RUI:GetRetreatStyleInfo() or nil
    Chat("Core " .. tostring(RUI.version or "?") .. " | Profile: " .. tostring(style and style.label or "none") .. " | HUD: user-built")
    return
  end
  if command == "reset" then
    local db = type(RUI.EnsureDB) == "function" and RUI:EnsureDB() or nil
    if db then db.profileStyle = {} end
    if type(RUI.CloseHUDBarUnlockMode) == "function" then RUI:CloseHUDBarUnlockMode() end
    if type(RUI.OpenRetreatUI) == "function" then RUI:OpenRetreatUI("profiles") end
    return
  end

  Chat("Commands: /rui | /rui hud | /rui unlock | /rui settings | /rui buffs | /rui status | /rui reset")
end

RUI._beta50NavigationLoaded = true
RUI.beta50NavigationSchema = 1
