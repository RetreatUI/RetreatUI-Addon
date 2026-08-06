local RUI = RetreatUI
if not RUI or RUI._hudDefinitionDedupInstalled then return end

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return string.lower(value)
end

local function DefinitionKeys(definition)
  if type(definition) ~= "table" then return {"value:" .. tostring(definition)} end
  local keys, seen = {}, {}
  local function Add(prefix, value)
    if value == nil then return end
    local normalized = prefix == "id:" and tostring(tonumber(value) or "") or Normalize(value)
    if normalized == "" then return end
    local key = prefix .. normalized
    if not seen[key] then
      seen[key] = true
      keys[#keys + 1] = key
    end
  end

  Add("name:", definition.name)
  Add("id:", definition.id or definition.spellID)
  for _, alias in ipairs(definition.aliases or {}) do Add("name:", alias) end
  return keys
end

function RUI:DeduplicateHUDDefinitions(definitions)
  local result, claimed = {}, {}
  for _, definition in ipairs(definitions or {}) do
    local keys = DefinitionKeys(definition)
    local duplicate = false
    if type(definition) == "table" and definition.allowDuplicateHUD == true then
      duplicate = false
    else
      for _, key in ipairs(keys) do
        if claimed[key] then
          duplicate = true
          break
        end
      end
    end

    if not duplicate then
      result[#result + 1] = definition
      if not (type(definition) == "table" and definition.allowDuplicateHUD == true) then
        for _, key in ipairs(keys) do claimed[key] = definition end
      end
    end
  end
  return result
end

function RUI:FindHUDDefinitionDuplicates(definitions)
  local duplicates, claimed = {}, {}
  for index, definition in ipairs(definitions or {}) do
    if not (type(definition) == "table" and definition.allowDuplicateHUD == true) then
      for _, key in ipairs(DefinitionKeys(definition)) do
        if claimed[key] then
          duplicates[#duplicates + 1] = {
            key = key,
            first = claimed[key],
            duplicate = definition,
            index = index,
          }
          break
        end
        claimed[key] = definition
      end
    end
  end
  return duplicates
end

local originalHUDDefinitions = RUI.GetHUDSpellDefinitions
if type(originalHUDDefinitions) == "function" then
  RUI.GetHUDSpellDefinitions = function(self, className, row, ...)
    return self:DeduplicateHUDDefinitions(originalHUDDefinitions(self, className, row, ...))
  end
end

local originalTankDefinitions = RUI.GetTankHUDDefinitions
if type(originalTankDefinitions) == "function" then
  RUI.GetTankHUDDefinitions = function(self, className, row, ...)
    return self:DeduplicateHUDDefinitions(originalTankDefinitions(self, className, row, ...))
  end
end

local W = RUI.HUDWidgets
if W and type(W.BuildSpellRow) == "function" then
  local originalBuildSpellRow = W.BuildSpellRow
  W.BuildSpellRow = function(self, row, definitions, ...)
    definitions = RUI:DeduplicateHUDDefinitions(definitions)
    return originalBuildSpellRow(self, row, definitions, ...)
  end
end

RUI._hudDefinitionDedupInstalled = true
