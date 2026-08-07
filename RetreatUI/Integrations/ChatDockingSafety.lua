local RUI = RetreatUI
if not RUI then return end

-- RetreatUI previously attempted to remove standalone Loot/Trade chat windows by
-- undocking and closing matching Blizzard chat frames after world entry. Newly
-- created ElvUI tabs are not guaranteed to have finished attaching to their
-- panel at that point, which can leave a tab undocked at the same coordinates
-- as the active chat window and make two chats render on top of each other.
--
-- Chat ownership now belongs entirely to ElvUI/Blizzard. RetreatUI may style
-- chat through the ElvUI profile, but must never dock, undock, close, hide or
-- reposition chat frames at runtime.
function RUI:RemoveRightLootTradeChat()
  local db = type(self.EnsureDB) == "function" and self:EnsureDB() or nil
  if db then
    db.integrations = db.integrations or {}
    db.integrations.elvui = db.integrations.elvui or {}
    db.integrations.elvui.chatDockingOwnedByElvUI = true
    db.integrations.elvui.chatDockingSafetyVersion = tostring(self.version or "unknown")
  end
  return false
end
