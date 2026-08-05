local RUI = RetreatUI
if not RUI then return end

-- Global action-row guard ----------------------------------------------------
-- Stances, forms, presences, vows, aspects, oaths, attunements, modes,
-- imbues and other persistent class states are owned by StateTracker. Their
-- activation spell must never re-enter Main Rotation, Utility, Offensive or
-- Defensive merely because it has a short cooldown or is labelled Offensive.
local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  return string.lower(value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local STATE_CATEGORIES = {
  stance=true,
  form=true,
  presence=true,
  vow=true,
  aspect=true,
  oath=true,
  attunement=true,
  mode=true,
  imbue=true,
  state=true,
  transformation=true,
  style=true,
  formation=true,
  pact=true,
  augmentation=true,
  ascendance=true,
}

local function IsStateRecord(className, record)
  if type(record) ~= "table" then return false end
  if record.classState == true or record.stateTracker == true then return true end

  local category = Normalize(record.category)
  if STATE_CATEGORIES[category] then return true end

  if RUI.IsClassStateAuraDefinition then
    local ok, result = pcall(RUI.IsClassStateAuraDefinition, RUI, className, record)
    if ok and result then return true end
  end

  if RUI.IsClassStateName then
    local names = {record.name, record.buff}
    for _, alias in ipairs(record.aliases or {}) do names[#names + 1] = alias end
    for _, name in ipairs(names) do
      if name then
        local ok, result = pcall(RUI.IsClassStateName, RUI, className, name)
        if ok and result then return true end
      end
    end
  end

  return false
end

local function Filter(className, records)
  local result = {}
  for _, record in ipairs(records or {}) do
    if not IsStateRecord(className, record) then result[#result + 1] = record end
  end
  return result
end

if not RUI._stateHUDGuardInstalled then
  local OriginalGetHUDSpellDefinitions = RUI.GetHUDSpellDefinitions
  function RUI:GetHUDSpellDefinitions(className, row)
    className = className or (self.GetDetectedClass and self:GetDetectedClass())
    local records = OriginalGetHUDSpellDefinitions and OriginalGetHUDSpellDefinitions(self, className, row) or {}
    return Filter(className, records)
  end

  local OriginalGetClassCooldownRowDefinitions = RUI.GetClassCooldownRowDefinitions
  function RUI:GetClassCooldownRowDefinitions(className, row)
    className = className or (self.GetDetectedClass and self:GetDetectedClass())
    local records = OriginalGetClassCooldownRowDefinitions
      and OriginalGetClassCooldownRowDefinitions(self, className, row) or {}
    return Filter(className, records)
  end

  RUI._stateHUDGuardInstalled = true
end
