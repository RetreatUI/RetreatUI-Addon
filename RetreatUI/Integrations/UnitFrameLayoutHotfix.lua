local RUI = RetreatUI
if not RUI then return end

local REVISION = 2026080601
local OLD_TOTEM_MOVER = "BOTTOM,ElvUIParent,BOTTOM,0,55"
local NEW_TOTEM_MOVER = "BOTTOM,ElvUIParent,BOTTOM,0,132"

local function RepairProfile(profile)
  if type(profile) ~= "table" then return false end
  local changed = false

  profile.movers = profile.movers or {}
  if profile.movers.ElvBar_Totem == OLD_TOTEM_MOVER or profile.movers.ElvBar_Totem == nil then
    profile.movers.ElvBar_Totem = NEW_TOTEM_MOVER
    changed = true
  end

  profile.unitframe = profile.unitframe or {}
  profile.unitframe.units = profile.unitframe.units or {}
  local party = profile.unitframe.units.party
  if type(party) == "table" then
    party.width = math.max(200, tonumber(party.width) or 0)
    party.height = math.max(42, tonumber(party.height) or 0)

    party.name = party.name or {}
    party.name.font = RUI.fontName or party.name.font or "Fira Sans Heavy"
    party.name.fontOutline = "OUTLINE"
    party.name.fontSize = 10
    party.name.position = "TOPLEFT"
    party.name.text_format = "[name:medium]"
    party.name.xOffset = 5
    party.name.yOffset = -4

    party.health = party.health or {}
    party.health.frequentUpdates = true
    party.health.position = "BOTTOMRIGHT"
    party.health.text_format = "[health:percent]"
    party.health.xOffset = -5
    party.health.yOffset = 4

    party.power = party.power or {}
    party.power.height = math.max(4, tonumber(party.power.height) or 0)
    party.power.text_format = ""
    changed = true
  end

  return changed
end

function RUI:ApplyUnitFrameLayoutHotfix()
  local changed = RepairProfile(self.ElvUIProfile)

  if type(ElvDB) == "table" and type(ElvDB.profiles) == "table" then
    changed = RepairProfile(ElvDB.profiles.RetreatUI) or changed
  end

  if ElvUI then
    local E = unpack(ElvUI)
    local currentProfile
    if E and E.data and type(E.data.GetCurrentProfile) == "function" then
      local ok, value = pcall(E.data.GetCurrentProfile, E.data)
      if ok then currentProfile = value end
    end

    local activeUsesRetreat = currentProfile == "RetreatUI"
      or (E and E.db and E.db.movers and E.db.movers.ElvBar_Totem == OLD_TOTEM_MOVER)
    if activeUsesRetreat and E and type(E.db) == "table" then
      changed = RepairProfile(E.db) or changed
      if changed and type(E.UpdateAll) == "function" then
        pcall(E.UpdateAll, E, true)
      end
    end
  end

  local db = self:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.unitFrameLayoutHotfix = {
    revision = REVISION,
    applied = true,
    changed = changed == true,
    guardianTotemY = 132,
    partyName = "top-left",
    partyHealth = "bottom-right",
  }
  return true, changed and "Party frames and Guardian totem position repaired" or "Unit-frame layout already current"
end

for _, delay in ipairs({0.30, 1.00, 3.00}) do
  if RUI.After then
    RUI:After(delay, function()
      if RUI and RUI.ApplyUnitFrameLayoutHotfix then
        RUI:ApplyUnitFrameLayoutHotfix()
      end
    end)
  end
end
