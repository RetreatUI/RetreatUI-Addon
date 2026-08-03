local RUI = RetreatUI
if not RUI then return end

-- Ascension sometimes exposes a selected talent/base spell in the spellbook,
-- while the actual button uses another internal ID for cooldowns or charges.
-- These optional record fields keep detection and runtime tracking separate:
--   learnedBySpellID / learnedBySpell / learnedByAny
--   runtimeID / runtimeIDs / chargeSpellID / chargeSpellIDs
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

local function AddCandidate(result, seen, value)
  if value == nil then return end
  value = tonumber(value) or value
  local key = tostring(value)
  if key == "" or seen[key] then return end
  seen[key] = true
  result[#result + 1] = value
end

local function RuntimeCandidates(record, includeDefault)
  local result, seen = {}, {}
  if type(record) == "table" then
    AddCandidate(result, seen, record.runtimeID)
    for _, value in ipairs(record.runtimeIDs or {}) do AddCandidate(result, seen, value) end
  end
  if includeDefault and type(originalGetSpellRecordRuntimeID) == "function" then
    AddCandidate(result, seen, originalGetSpellRecordRuntimeID(RUI, record))
  end
  return result
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

    for _, value in ipairs(record.runtimeIDs or {}) do
      if ReferenceLearned(self, value) then return true end
    end
  end

  return originalIsSpellRecordLearned(self, record)
end

function RUI:GetSpellRecordRuntimeID(record)
  local candidates = RuntimeCandidates(record, false)
  for _, value in ipairs(candidates) do
    if ReferenceLearned(self, value) then return value end
  end
  if candidates[1] ~= nil then return candidates[1] end
  return originalGetSpellRecordRuntimeID(self, record)
end

local W = RUI.HUDWidgets
if W then
  if type(W.ReadSpellCooldown) == "function" then
    local originalReadSpellCooldown = W.ReadSpellCooldown

    function W:ReadSpellCooldown(definition)
      if GetSpellCooldown and type(definition) == "table" then
        local fallback
        for _, runtimeID in ipairs(RuntimeCandidates(definition, false)) do
          local ok, start, duration, enabled = pcall(GetSpellCooldown, runtimeID)
          if ok and start ~= nil and duration ~= nil then
            local snapshot = {tonumber(start) or 0, tonumber(duration) or 0, tonumber(enabled) or 0}
            fallback = fallback or snapshot
            if snapshot[2] > 0 then return snapshot[1], snapshot[2], snapshot[3] end
          end
        end
        if fallback then return fallback[1], fallback[2], fallback[3] end
      end
      return originalReadSpellCooldown(self, definition)
    end
  end

  if type(W.ReadSpellCharges) == "function" then
    local originalReadSpellCharges = W.ReadSpellCharges

    function W:ReadSpellCharges(definition)
      if GetSpellCharges and type(definition) == "table" then
        local candidates, seen = {}, {}
        AddCandidate(candidates, seen, definition.chargeSpellID)
        for _, value in ipairs(definition.chargeSpellIDs or {}) do AddCandidate(candidates, seen, value) end
        for _, value in ipairs(definition.runtimeIDs or {}) do AddCandidate(candidates, seen, value) end

        for _, spellID in ipairs(candidates) do
          local ok, current, maximum, start, duration = pcall(GetSpellCharges, spellID)
          current, maximum = tonumber(current), tonumber(maximum)
          if ok and current and maximum and maximum > 0 then
            return current, maximum, tonumber(start) or 0, tonumber(duration) or 0
          end
        end
      end
      return originalReadSpellCharges(self, definition)
    end
  end
end

RUI._spellRecordRuntimeLoaded = true
