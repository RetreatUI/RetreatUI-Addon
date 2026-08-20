local RUI = RetreatUI
if not RUI then return end

local previous = SlashCmdList and SlashCmdList["RETREATUI"]
if type(previous) ~= "function" then return end

SlashCmdList["RETREATUI"] = function(message)
  local command = string.lower((message or ""):match("^%s*(.-)%s*$"))
  if command == "hud" or command == "editor" or command == "tracker" or command == "trackers" or command == "builder" then
    if type(RUI.OpenRetreatUI) == "function" then
      local ok, err = pcall(RUI.OpenRetreatUI, RUI, "hud")
      if not ok and RUI.BootstrapPrint then RUI.BootstrapPrint("The HUD workspace could not open: " .. tostring(err)) end
      return
    end
  end
  return previous(message)
end

RUI._hudWorkspaceSlashLoaded = true
