local RUI = RetreatUI
if not RUI or type(RUI.GetClassSpellDatabase) ~= "function" then return end

-- User-verified Eternal Bloodmage tooltips (2026-08-05).
-- These semantic overrides deliberately win over older generated categories:
--   Wicked Howl    = defensive self-health cooldown -> Utility
--   Eternal Resolve = offensive frenzy cooldown       -> Main
local CORRECTIONS = {
  ["wicked howl"] = {
    category = "defensive",
    cooldownCategory = "defensive",
    hudRow = "utility",
    forceMain = false,
    forceUtility = true,
    tankSlot = "defensive",
    targetDebuff = false,
    buff = "Wicked Howl",
    trackDuration = true,
    cooldownHint = 120,
    classificationSource = "UserVerifiedTooltip-2026-08-05",
  },
  ["eternal resolve"] = {
    category = "offensive",
    cooldownCategory = "offensive",
    hudRow = "core",
    forceMain = true,
    forceUtility = false,
    tankSlot = "offensive",
    buff = "Eternal Resolve",
    trackDuration = true,
    cooldownHint = 180,
    classificationSource = "UserVerifiedTooltip-2026-08-05",
  },
}

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  return string.lower(value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local database = RUI:GetClassSpellDatabase("Bloodmage")
if not database or type(database.spells) ~= "table" then return end

for _, record in ipairs(database.spells) do
  local correction = CORRECTIONS[Normalize(record.name)]
  if correction then
    for field, value in pairs(correction) do
      record[field] = value
    end
  end
end

RUI._eternalBloodmageClassificationVerified = true
