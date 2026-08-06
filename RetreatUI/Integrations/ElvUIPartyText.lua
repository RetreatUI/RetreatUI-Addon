local RUI = RetreatUI
if not RUI then return end

local PARTY_TEXT_REVISION = 1

local function ConfigurePartyText(profile)
  if type(profile) ~= "table" then return false end
  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  profile.unitframe.units.party = profile.unitframe.units.party or {}
  local party = profile.unitframe.units.party
  local changed = false

  party.name = party.name or {}
  local name = party.name
  local nameSettings = {
    attachTextTo = "Health",
    font = "Fira Sans Heavy",
    fontOutline = "OUTLINE",
    fontSize = 10,
    position = "LEFT",
    text_format = "[name:short]",
    xOffset = 5,
    yOffset = 0,
  }
  for key, value in pairs(nameSettings) do
    if name[key] ~= value then
      name[key] = value
      changed = true
    end
  end

  party.health = party.health or {}
  local health = party.health
  local healthSettings = {
    attachTextTo = "Health",
    font = "Fira Sans Heavy",
    fontOutline = "OUTLINE",
    fontSize = 10,
    frequentUpdates = true,
    position = "RIGHT",
    text_format = "[health:percent]",
    xOffset = -5,
    yOffset = 0,
  }
  for key, value in pairs(healthSettings) do
    if health[key] ~= value then
      health[key] = value
      changed = true
    end
  end

  -- The four-pixel power strip remains visible, but its text is intentionally
  -- empty so it cannot collide with either the player name or health value.
  party.power = party.power or {}
  if party.power.text_format ~= "" then
    party.power.text_format = ""
    changed = true
  end
  if party.power.position ~= "CENTER" then
    party.power.position = "CENTER"
    changed = true
  end

  return changed
end

-- Update the packaged baseline before the installer copies it into ElvDB.
if type(RUI.ElvUIProfile) == "table" then ConfigurePartyText(RUI.ElvUIProfile) end

function RUI:ApplyElvUIPartyTextLayout(refreshLive)
  local changed = false
  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    changed = ConfigurePartyText(ElvDB.profiles.RetreatUI) or changed
  end

  local E = ElvUI and unpack(ElvUI)
  local currentProfile
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok then currentProfile = value end
  end
  if currentProfile == "RetreatUI" and E and E.db then
    changed = ConfigurePartyText(E.db) or changed
  end

  local db = self:EnsureDB()
  db.integrations.elvui = db.integrations.elvui or {}
  db.integrations.elvui.partyTextRevision = PARTY_TEXT_REVISION
  db.integrations.elvui.partyTextVersion = self.version

  if refreshLive and E and currentProfile == "RetreatUI" then
    if E.UpdateAll then pcall(E.UpdateAll, E, true) end
    self:After(0.25, function()
      if E and E.UpdateAll then pcall(E.UpdateAll, E, true) end
    end)
  end

  return true, changed
    and "Party-frame name and health text separated"
    or "Party-frame text layout verified"
end

-- Keep install/repair paths synchronous while also covering ordinary updates.
local originalInstallElvUIProfile = RUI.InstallElvUIProfile
if type(originalInstallElvUIProfile) == "function" then
  function RUI:InstallElvUIProfile(...)
    local ok, message = originalInstallElvUIProfile(self, ...)
    if ok then self:ApplyElvUIPartyTextLayout(true) end
    return ok, message
  end
end

local frame = CreateFrame("Frame", "RetreatUIElvUIPartyTextLayout", UIParent)
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function()
  RUI:After(0.20, function() RUI:ApplyElvUIPartyTextLayout(true) end)
end)

RUI.elvUIPartyTextRevision = PARTY_TEXT_REVISION
