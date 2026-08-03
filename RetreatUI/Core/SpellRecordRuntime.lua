local RUI = RetreatUI
if not RUI then return end

-- Ascension sometimes exposes a selected talent/base spell in the spellbook,
-- while the actual button uses another internal ID for cooldowns or charges.
-- These optional record fields keep detection and runtime tracking separate:
--   learnedBySpellID / learnedBySpell / learnedByAny
--   runtimeID / chargeSpellID
local originalIsSpellRecordLearned = RUI.IsSpellRecordLearned
local originalGetSpellRecordRuntimeID = RUI.GetSpellRecordRuntimeID

if type(originalIsSpellRecordLearned) ~= "function"
  or type(originalGetSpellRecordRuntimeID) ~= "function" then
  return
end

local function ReferenceLearned(self, value)
  if type(value) == "number" then
    return self.IsSpellIDLearned and self:IsSpellIDLearned(value) == true
  end
  if type(value) == "string" then
    return self.IsSpellLearned and self:IsSpellLearned(value) == true
  end
  if type(value) == "table" then
    local spellID = value.spellID or value.id
    if spellID and self.IsSpellIDLearned and self:IsSpellIDLearned(spellID) then return true end
    if value.name and self.IsSpellLearned and self:IsSpellLearned(value.name) then return true end
  end
  return false
end

function RUI:IsSpellRecordLearned(record)
  if type(record) == "table" then
    if record.learnedBySpellID and ReferenceLearned(self, tonumber(record.learnedBySpellID)) then return true end
    if record.learnedBySpell and ReferenceLearned(self, record.learnedBySpell) then return true end

    local values = record.learnedByAny
    if values ~= nil then
      if type(values) ~= "table" then values = {values} end
      for _, value in ipairs(values) do
        if ReferenceLearned(self, value) then return true end
      end
    end
  end

  return originalIsSpellRecordLearned(self, record)
end

function RUI:GetSpellRecordRuntimeID(record)
  if type(record) == "table" and record.runtimeID ~= nil then
    return tonumber(record.runtimeID) or record.runtimeID
  end
  return originalGetSpellRecordRuntimeID(self, record)
end

local W = RUI.HUDWidgets
if W then
  if type(W.ReadSpellCooldown) == "function" then
    local originalReadSpellCooldown = W.ReadSpellCooldown

    function W:ReadSpellCooldown(definition)
      local runtimeID = type(definition) == "table" and definition.runtimeID or nil
      if runtimeID and GetSpellCooldown then
        local ok, start, duration, enabled = pcall(GetSpellCooldown, runtimeID)
        if ok and start ~= nil and duration ~= nil then
          return tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0
        end
      end
      return originalReadSpellCooldown(self, definition)
    end
  end

  if type(W.ReadSpellCharges) == "function" then
    local originalReadSpellCharges = W.ReadSpellCharges

    function W:ReadSpellCharges(definition)
      local chargeSpellID = type(definition) == "table" and definition.chargeSpellID or nil
      if chargeSpellID and GetSpellCharges then
        local ok, current, maximum, start, duration = pcall(GetSpellCharges, chargeSpellID)
        current, maximum = tonumber(current), tonumber(maximum)
        if ok and current and maximum and maximum > 0 then
          return current, maximum, tonumber(start) or 0, tonumber(duration) or 0
        end
      end
      return originalReadSpellCharges(self, definition)
    end
  end
end

RUI._spellRecordRuntimeLoaded = true
