local RUI = RetreatUI
if not RUI then return end

function RUI:GetActiveElvUIProfileName()
  if type(ElvDB) ~= "table" or type(ElvDB.profileKeys) ~= "table" then return nil end
  local E = type(ElvUI) == "table" and ElvUI[1] or nil
  local key = E and E.mynameRealm
  return key and ElvDB.profileKeys[key] or nil
end

RUI._profileSwitchDiagnostics = true
