local RUI = RetreatUI
if not RUI or type(RUI.InitializePartyUtilityTracker) ~= "function" then return end

-- Ascension legacy combat-log events were verified live to contain the complete
-- party spell ID/name payload. UNIT_SPELLCAST_SUCCEEDED, however, can append
-- rank/action values that look like spell IDs (for example a real cast name
-- paired with 72), which can collide with old WotLK IDs such as Shield Bash.
--
-- Keep RetreatCD's combat-log, pet-GUID and addon-sync paths, but suppress its
-- unreliable party unit-event fallback on this client. No global API is changed.

local originalInitialize = RUI.InitializePartyUtilityTracker
local installed = false

local function InstallGuard()
  local driver = _G.RetreatUIPartyUtilityDriverV4
  if not driver then return false end
  if driver.__retreatCDUnitGuard then installed = true return true end
  if type(driver.GetScript) ~= "function" or type(driver.SetScript) ~= "function" then return false end

  local previous = driver:GetScript("OnEvent")
  if type(previous) ~= "function" then return false end

  driver:SetScript("OnEvent", function(frame, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      return
    end
    return previous(frame, event, ...)
  end)

  driver.__retreatCDUnitGuard = true
  installed = true
  return true
end

function RUI:InitializePartyUtilityTracker(...)
  local results = {originalInitialize(self, ...)}
  InstallGuard()
  return unpack(results)
end

function RUI:GetRetreatCDUnitGuardStatus()
  return installed
end

RUI._retreatCDUnitGuardLoaded = true
