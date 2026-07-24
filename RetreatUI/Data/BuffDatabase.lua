local RUI = RetreatUI

RUI.buffDatabaseVersion = 1

local function SortedBuffs(records)
  table.sort(records, function(left, right)
    local leftOrder = tonumber(left.order) or 9999
    local rightOrder = tonumber(right.order) or 9999
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end

    local leftSpec = tostring(left.spec or "")
    local rightSpec = tostring(right.spec or "")
    if leftSpec ~= rightSpec then return leftSpec < rightSpec end

    return tostring(left.name or "") < tostring(right.name or "")
  end)
  return records
end

-- Returns the castable, long-duration party/raid buffs catalogued for a class.
-- Options:
--   includeReview = true  Include records that still need an in-game ID check.
--   learnedOnly   = true  Only return buffs found in the current spellbook.
function RUI:GetGroupBuffDefinitions(className, options)
  options = type(options) == "table" and options or {}
  local result = {}

  for _, record in ipairs(self:GetClassSpellRecords(className)) do
    if record.groupBuff == true
      and (options.includeReview == true or record.review ~= true)
      and (options.learnedOnly ~= true or self:IsSpellRecordLearned(record)) then
      result[#result + 1] = record
    end
  end

  return SortedBuffs(result)
end

function RUI:GetAllGroupBuffDefinitions(options)
  local result = {}

  for className in pairs(self.spellDatabase or {}) do
    for _, record in ipairs(self:GetGroupBuffDefinitions(className, options)) do
      result[#result + 1] = record
    end
  end

  return SortedBuffs(result)
end

function RUI:GetGroupBuffRecordBySpellID(spellID, className)
  spellID = tonumber(spellID)
  if not spellID then return nil end

  local classes = {}
  if className then
    classes[1] = className
  else
    for registeredClass in pairs(self.spellDatabase or {}) do
      classes[#classes + 1] = registeredClass
    end
  end

  for _, registeredClass in ipairs(classes) do
    for _, record in ipairs(self:GetGroupBuffDefinitions(registeredClass, {includeReview=true})) do
      if tonumber(record.id) == spellID or tonumber(record.auraID) == spellID then
        return record, registeredClass
      end
    end
  end

  return nil
end
