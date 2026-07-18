local RUI = RetreatUI

local CVARS = {
  nameplateMaxDistance = "41",
  cameraDistanceMaxZoomFactor = "2.6",
  ActionButtonUseKeyDown = "1",
  SpellQueueWindow = "150",
  nameplateShowEnemies = "1",
  nameplateShowFriends = "0",
  nameplateOverlapH = "0.8",
  nameplateOverlapV = "1.1",
}

function RUI:ApplyCVars()
  if not SetCVar then return false, "SetCVar is unavailable" end
  local changed = 0
  for name, value in pairs(CVARS) do
    local ok = pcall(SetCVar, name, value)
    if ok then changed = changed + 1 end
  end
  local combatOK, combatMessage = false, nil
  if type(self.ApplyCombatTextStyle) == "function" then
    combatOK, combatMessage = self:ApplyCombatTextStyle()
  end
  local message = tostring(changed) .. " CVars applied"
  if combatMessage then message = message .. "; " .. tostring(combatMessage) end
  return changed > 0 or combatOK == true, message
end
