local RUI = RetreatUI
if not RUI or type(RUI.GetHUDSpellDefinitions) ~= "function" then return end
if RUI._hudDuplicateGuardInstalled then return end
RUI._hudDuplicateGuardInstalled = true

local originalGetHUDSpellDefinitions = RUI.GetHUDSpellDefinitions

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  value = value:gsub("%s*%([Rr]ank%s+%d+%)$", "")
  return string.lower(value)
end

local function AddKey(keys, seen, prefix, value)
  if value == nil then return end
  local normalized = prefix == "name:" and Normalize(value) or tostring(value)
  if normalized == "" then return end
  local key = prefix .. normalized
  if not seen[key] then
    seen[key] = true
    keys[#keys + 1] = key
  end
end

local function IdentityKeys(self, record)
  local keys, localSeen = {}, {}
  if type(record) ~= "table" then return keys end

  AddKey(keys, localSeen, "name:", record.name)
  for _, alias in ipairs(record.aliases or {}) do
    AddKey(keys, localSeen, "name:", alias)
  end

  AddKey(keys, localSeen, "id:", record.id)
  if type(self.GetSpellRecordRuntimeID) == "function" then
    AddKey(keys, localSeen, "id:", self:GetSpellRecordRuntimeID(record))
  end
  if type(self.GetSpellRecordBookIndex) == "function" then
    AddKey(keys, localSeen, "book:", self:GetSpellRecordBookIndex(record))
  end
  return keys
end

function RUI:GetHUDSpellDefinitions(className, row)
  local definitions = originalGetHUDSpellDefinitions(self, className, row) or {}
  local result, seen = {}, {}

  for _, record in ipairs(definitions) do
    local keys = IdentityKeys(self, record)
    local duplicate = false
    for _, key in ipairs(keys) do
      if seen[key] then
        duplicate = true
        break
      end
    end

    if not duplicate then
      result[#result + 1] = record
      for _, key in ipairs(keys) do seen[key] = true end
    end
  end
  return result
end

RUI.hudDuplicateGuardVersion = 1
