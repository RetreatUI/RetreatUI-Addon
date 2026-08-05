local RUI = RetreatUI
if not RUI then return end

local FIRST_LINE_MAXIMUM = 9
local MAIN_ICON_MINIMUM = 36

-- Kept public so the layout rule can be validated without loading the game UI.
function RUI:SplitMainBarDefinitions(definitions, firstLineMaximum)
  local first, overflow = {}, {}
  firstLineMaximum = math.max(1, math.floor(tonumber(firstLineMaximum) or FIRST_LINE_MAXIMUM))
  for index, definition in ipairs(definitions or {}) do
    if index <= firstLineMaximum then
      first[#first + 1] = definition
    else
      overflow[#overflow + 1] = definition
    end
  end
  return first, overflow
end

local W = RUI.HUDWidgets
if not W or type(W.BuildSpellRow) ~= "function" or RUI._mainBarWrapInstalled then return end

local OriginalBuildSpellRow = W.BuildSpellRow
local overflowByParent = setmetatable({}, {__mode="k"})

local function Normalize(value)
  value = tostring(value or ""):gsub("’", "'")
  return string.lower(value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function RecordKey(definition)
  if type(definition) ~= "table" then return tostring(definition or "") end
  local name = Normalize(definition.name)
  if name ~= "" then return "name:" .. name end
  if definition.id then return "id:" .. tostring(definition.id) end
  return tostring(definition)
end

local function MergeOverflowWithUtility(overflow, utility)
  local result, seen = {}, {}
  local function Add(definition)
    local key = RecordKey(definition)
    if key == "" or seen[key] then return end
    seen[key] = true
    result[#result + 1] = definition
  end

  -- Main overflow remains first on the second line; defensive and normal
  -- utility abilities follow in their existing sorted order.
  for _, definition in ipairs(overflow or {}) do Add(definition) end
  for _, definition in ipairs(utility or {}) do Add(definition) end
  return result
end

function W:BuildSpellRow(row, definitions, size, spacing, learnedCallback, textureCallback)
  size = tonumber(size) or 0
  local parent = row and row.GetParent and row:GetParent() or nil

  if size >= MAIN_ICON_MINIMUM then
    local first, overflow = RUI:SplitMainBarDefinitions(definitions, FIRST_LINE_MAXIMUM)
    if parent then overflowByParent[parent] = overflow end
    row.__ruiMainBarFirstLineCount = #first
    row.__ruiMainBarOverflowCount = #overflow
    row.__ruiMainBarWrapped = #overflow > 0
    return OriginalBuildSpellRow(self, row, first, size, spacing, learnedCallback, textureCallback)
  end

  if parent then
    definitions = MergeOverflowWithUtility(overflowByParent[parent], definitions)
    row.__ruiMergedMainOverflowCount = #(overflowByParent[parent] or {})
  end
  return OriginalBuildSpellRow(self, row, definitions, size, spacing, learnedCallback, textureCallback)
end

RUI._mainBarWrapInstalled = true
RUI._mainOverflowMergedIntoUtility = true
