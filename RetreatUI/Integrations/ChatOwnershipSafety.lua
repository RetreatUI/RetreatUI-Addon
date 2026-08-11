local RUI = RetreatUI
if not RUI then return end

local CHAT_SAFETY_REVISION = 4
local repairScheduled = false
local repairedThisSession = false

-- Permanent replacement for the historical Loot/Trade cleanup. Older code in
-- Integrations/ElvUI.lua can remain for compatibility, but every caller now
-- lands here and can no longer dock, undock, close, hide or show chat frames.
function RUI:RemoveRightLootTradeChat()
  local db = type(self.EnsureDB) == "function" and self:EnsureDB() or nil
  if db then
    db.integrations = db.integrations or {}
    db.integrations.elvui = db.integrations.elvui or {}
    db.integrations.elvui.chatDockingOwnedByElvUI = true
    db.integrations.elvui.chatDockingSafetyRevision = CHAT_SAFETY_REVISION
    db.integrations.elvui.chatDockingSafetyVersion = tostring(self.version or "unknown")
  end
  return false
end

local function ClearHistoricalMarkers()
  local count = tonumber(NUM_CHAT_WINDOWS) or 10
  for index = 1, count do
    local frame = _G["ChatFrame" .. index]
    if frame then frame.RetreatUIHiddenBehindDetails = nil end
  end
end

function RUI:RepairChatDockVisibility()
  if repairedThisSession then return true end
  if type(InCombatLockdown) == "function" and InCombatLockdown() then return false end

  ClearHistoricalMarkers()

  -- FCF_DockUpdate does not create/delete tabs or change dock membership. It
  -- asks Blizzard's own chat dock to recompute the visibility/position of the
  -- windows already in that dock. This repairs the common legacy state where
  -- ChatFrame1 was force-shown underneath the selected Party/custom tab.
  if type(FCF_DockUpdate) == "function" then pcall(FCF_DockUpdate) end

  repairedThisSession = true
  local db = type(self.EnsureDB) == "function" and self:EnsureDB() or nil
  if db then
    db.integrations = db.integrations or {}
    db.integrations.elvui = db.integrations.elvui or {}
    db.integrations.elvui.chatVisibilityRepairRevision = CHAT_SAFETY_REVISION
    db.integrations.elvui.chatVisibilityRepairVersion = tostring(self.version or "unknown")
  end
  return true
end

local events = CreateFrame("Frame", "RetreatUIChatOwnershipSafetyDriver")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
  if repairedThisSession then
    events:UnregisterAllEvents()
    return
  end
  if repairScheduled and event ~= "PLAYER_REGEN_ENABLED" then return end
  repairScheduled = true
  if type(RUI.After) == "function" then
    RUI:After(0.35, function()
      repairScheduled = false
      if RUI:RepairChatDockVisibility() then events:UnregisterAllEvents() end
    end)
  else
    repairScheduled = false
    if RUI:RepairChatDockVisibility() then events:UnregisterAllEvents() end
  end
end)

RUI._chatOwnershipSafetyLoaded = true
