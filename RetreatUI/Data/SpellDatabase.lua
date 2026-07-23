local RUI = RetreatUI

RUI.spellDatabase = RUI.spellDatabase or {}
RUI.spellDatabaseVersion = 1


local function Normalize(value)
  if type(value) ~= "string" then return "" end
  return string.lower(value):gsub("^%s+", ""):gsub("%s+$", "")
end


function RUI:RegisterClassSpellDatabase(className, database)
  if type(className) ~= "string" or type(database) ~= "table" then return false end
  database.className = className
  database.version = tonumber(database.version) or 1
  database.spells = database.spells or {}
  database.resources = database.resources or {}
  self.spellDatabase[className] = database
  return true
end

function RUI:GetClassSpellDatabase(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  return self.spellDatabase[className]
end

function RUI:GetClassSpellRecords(className)
  local database = self:GetClassSpellDatabase(className)
  return database and database.spells or {}
end

function RUI:GetClassResourceRecords(className)
  local database = self:GetClassSpellDatabase(className)
  return database and database.resources or {}
end

function RUI:IsSpellRecordLearned(record)
  if type(record) ~= "table" then return false end

  -- Prefer the actual spellbook entry. Ascension talent IDs can sometimes
  -- point at a passive/advancement record rather than the castable spell.
  if record.name and self.IsSpellLearned and self:IsSpellLearned(record.name) then return true end
  for _, alias in ipairs(record.aliases or {}) do
    if self.IsSpellLearned and self:IsSpellLearned(alias) then return true end
  end
  if record.id and self.IsSpellIDLearned and self:IsSpellIDLearned(record.id) then return true end
  return false
end

function RUI:GetSpellRecordBookIndex(record)
  if type(record) ~= "table" then return nil end
  if not self.spellbook and self.ScanSpellbook then self:ScanSpellbook() end

  if record.name and self.GetSpellBookIndex then
    local index = self:GetSpellBookIndex(record.name)
    if index then return index end
  end
  for _, alias in ipairs(record.aliases or {}) do
    if self.GetSpellBookIndex then
      local index = self:GetSpellBookIndex(alias)
      if index then return index end
    end
  end
  if record.id and self.GetSpellBookIndexByID then
    return self:GetSpellBookIndexByID(record.id)
  end
  return nil
end

function RUI:GetSpellRecordRuntimeID(record)
  if type(record) ~= "table" then return nil end
  if not self.spellbook and self.ScanSpellbook then self:ScanSpellbook() end

  local function ByName(name)
    if not name or not self.spellbook or not self.spellbook.ids then return nil end
    return self.spellbook.ids[Normalize(name)]
  end

  local spellID = ByName(record.name)
  if spellID then return spellID end
  for _, alias in ipairs(record.aliases or {}) do
    spellID = ByName(alias)
    if spellID then return spellID end
  end
  return tonumber(record.id)
end



-- Talent-aware visibility helpers. These rules are deliberately data-driven so
-- class modules can describe replacements and passive conversions without
-- adding one-off conditionals to their HUD files.
local function AnyConditionLearned(self, values)
  if values == nil then return false end
  if type(values) ~= "table" then values = {values} end
  for _, value in ipairs(values) do
    if type(value) == "number" and self.IsSpellIDLearned and self:IsSpellIDLearned(value) then return true end
    if type(value) == "string" and self.IsSpellLearned and self:IsSpellLearned(value) then return true end
    if type(value) == "table" then
      if value.id and self.IsSpellIDLearned and self:IsSpellIDLearned(value.id) then return true end
      if value.name and self.IsSpellLearned and self:IsSpellLearned(value.name) then return true end
    end
  end
  return false
end

function RUI:IsSpellRecordPassive(record)
  if type(record) ~= "table" then return false end
  local spellID = self.GetSpellRecordRuntimeID and self:GetSpellRecordRuntimeID(record) or tonumber(record.id)
  if spellID and IsPassiveSpell then
    local ok, passive = pcall(IsPassiveSpell, spellID)
    if ok and passive then return true end
  end
  return record.passive == true
end

function RUI:IsSpellRecordCastable(record)
  if type(record) ~= "table" then return false end
  if self:IsSpellRecordPassive(record) then return false end
  if AnyConditionLearned(self, record.becomesPassiveWhen) then return false end
  return self:IsSpellRecordLearned(record)
end

function RUI:ShouldShowSpellRecord(record)
  if type(record) ~= "table" or record.disabled == true then return false end
  if record.hideIfSpellIDLearned and self.IsSpellIDLearned and self:IsSpellIDLearned(record.hideIfSpellIDLearned) then return false end
  if record.hideIfSpellLearned and self.IsSpellLearned and self:IsSpellLearned(record.hideIfSpellLearned) then return false end
  if AnyConditionLearned(self, record.hideWhen) then return false end
  if record.requiresSpellID and self.IsSpellIDLearned and not self:IsSpellIDLearned(record.requiresSpellID) then return false end
  if record.requiresSpell and self.IsSpellLearned and not self:IsSpellLearned(record.requiresSpell) then return false end
  if record.requiresAny and not AnyConditionLearned(self, record.requiresAny) then return false end
  if record.requiresAll then
    local values = type(record.requiresAll) == "table" and record.requiresAll or {record.requiresAll}
    for _, value in ipairs(values) do if not AnyConditionLearned(self, {value}) then return false end end
  end
  if record.hudRow and record.allowPassiveOnHUD ~= true and self:IsSpellRecordPassive(record) then return false end
  if record.hudRow and AnyConditionLearned(self, record.becomesPassiveWhen) then return false end
  return true
end

function RUI:GetSpellRecordTexture(record)
  if type(record) ~= "table" then return "Interface\\Icons\\INV_Misc_QuestionMark" end
  local texture

  -- Use the learned spellbook entry first. This keeps the HUD icon tied to
  -- the castable spell even when an Ascension talent ID resolves to another
  -- internal effect with a different icon.
  local bookIndex = self.GetSpellRecordBookIndex and self:GetSpellRecordBookIndex(record)
  if bookIndex and GetSpellBookItemTexture then
    local ok, result = pcall(GetSpellBookItemTexture, bookIndex, BOOKTYPE_SPELL or "spell")
    if ok then texture = result end
  end

  local _, _, infoTexture
  if not texture and record.name and GetSpellInfo then
    _, _, infoTexture = GetSpellInfo(record.name)
    texture = infoTexture
  end
  if not texture then
    for _, alias in ipairs(record.aliases or {}) do
      _, _, infoTexture = GetSpellInfo(alias)
      if infoTexture then texture = infoTexture break end
    end
  end
  if not texture and record.id and GetSpellInfo then
    _, _, texture = GetSpellInfo(record.id)
  end
  return texture or record.fallbackIcon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function SortedRecords(records)
  table.sort(records, function(left, right)
    local leftOrder = tonumber(left.order) or 9999
    local rightOrder = tonumber(right.order) or 9999
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end
    local leftGroup = tostring(left.group or "")
    local rightGroup = tostring(right.group or "")
    if leftGroup ~= rightGroup then return leftGroup < rightGroup end
    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return records
end

function RUI:GetHUDSpellDefinitions(className, row)
  local result = {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.hudRow == row and record.trackHUD ~= false and self:ShouldShowSpellRecord(record) then
      result[#result + 1] = record
    end
  end
  return SortedRecords(result)
end

function RUI:GetAuraTrackerDefinitions(className)
  local result = {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.auraTracker == true then result[#result + 1] = record end
  end
  return SortedRecords(result)
end

function RUI:GetTargetDebuffDefinitions(className)
  local result = {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.targetDebuff == true then result[#result + 1] = record end
  end
  return SortedRecords(result)
end

function RUI:GetPartyCooldownDefinitions(className, category)
  local result = {}
  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.partyCooldown == true and (not category or record.cooldownCategory == category) then
      result[#result + 1] = record
    end
  end
  return SortedRecords(result)
end

