local RUI = RetreatUI
if not RUI then return end

local FIRST_LINE_MAXIMUM = 9
local WRAP_GAP = 1
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
local parentStates = setmetatable({}, {__mode="k"})

local function Number(value, fallback)
  value = tonumber(value)
  if value == nil then return fallback end
  return value
end

local function IsShown(frame)
  if not frame then return false end
  if type(frame.IsShown) ~= "function" then return true end
  return frame:IsShown()
end

local function VisibleIcons(row)
  local result = {}
  for _, icon in ipairs(row and row.icons or {}) do
    if icon and icon.definition and IsShown(icon) then result[#result + 1] = icon end
  end
  return result
end

local function SameAnchor(anchor, point, relativeTo, relativePoint, x, y)
  if not anchor then return false end
  return anchor.point == point
    and anchor.relativeTo == relativeTo
    and anchor.relativePoint == relativePoint
    and math.abs(Number(anchor.x, 0) - Number(x, 0)) < 0.01
    and math.abs(Number(anchor.y, 0) - Number(y, 0)) < 0.01
end

local function ReadAnchor(row)
  if not row or type(row.GetPoint) ~= "function" then return nil end
  local point, relativeTo, relativePoint, x, y = row:GetPoint(1)
  if not point then return nil end
  return {
    point=point,
    relativeTo=relativeTo,
    relativePoint=relativePoint,
    x=Number(x, 0),
    y=Number(y, 0),
  }
end

local function SetAnchor(row, anchor, yOffset)
  if not row or not anchor or type(row.ClearAllPoints) ~= "function" or type(row.SetPoint) ~= "function" then return end
  row:ClearAllPoints()
  row:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y + Number(yOffset, 0))
end

local function CoreScale(row)
  if row and type(row.GetScale) == "function" then
    return Number(row:GetScale(), 1)
  end
  return 1
end

local function ApplyUtilityOffset(state)
  local utility = state and state.utilityRow
  if not utility then return end

  local current = ReadAnchor(utility)
  if current and not SameAnchor(state.lastAppliedUtilityAnchor,
      current.point, current.relativeTo, current.relativePoint, current.x, current.y) then
    state.baseUtilityAnchor = current
  end
  if not state.baseUtilityAnchor then return end

  local shift = 0
  if state.wrapped and state.mainRow then
    shift = -((Number(state.mainIconSize, 38) + Number(state.wrapGap, WRAP_GAP)) * CoreScale(state.mainRow))
  end

  local desired = {
    point=state.baseUtilityAnchor.point,
    relativeTo=state.baseUtilityAnchor.relativeTo,
    relativePoint=state.baseUtilityAnchor.relativePoint,
    x=state.baseUtilityAnchor.x,
    y=state.baseUtilityAnchor.y + shift,
  }
  local live = ReadAnchor(utility)
  if not live or not SameAnchor(desired, live.point, live.relativeTo, live.relativePoint, live.x, live.y) then
    SetAnchor(utility, state.baseUtilityAnchor, shift)
  end
  state.lastAppliedUtilityAnchor = desired
end

local function EnsureDriver(parent, state)
  if state.driver or type(CreateFrame) ~= "function" then return end
  local driver = CreateFrame("Frame", nil, parent)
  state.driver = driver
  state.elapsed = 0
  if driver.SetScript then
    driver:SetScript("OnUpdate", function(_, delta)
      state.elapsed = state.elapsed + Number(delta, 0)
      if state.elapsed < 0.20 then return end
      state.elapsed = 0
      ApplyUtilityOffset(state)
    end)
  end
end

local function RepositionMainRow(row, size, spacing)
  local icons = VisibleIcons(row)
  local count = #icons
  local firstCount = math.min(FIRST_LINE_MAXIMUM, count)
  local overflowCount = math.max(0, count - FIRST_LINE_MAXIMUM)
  local firstTotal = firstCount > 0 and (firstCount * size + (firstCount - 1) * spacing) or 0
  local overflowTotal = overflowCount > 0 and (overflowCount * size + (overflowCount - 1) * spacing) or 0

  for index, icon in ipairs(icons) do
    local lineIndex, lineCount, total, y
    if index <= FIRST_LINE_MAXIMUM then
      lineIndex, lineCount, total, y = index, firstCount, firstTotal, 0
    else
      lineIndex, lineCount, total, y = index - FIRST_LINE_MAXIMUM, overflowCount, overflowTotal, -(size + WRAP_GAP)
    end
    if lineCount > 0 and icon.ClearAllPoints and icon.SetPoint then
      icon:ClearAllPoints()
      icon:SetPoint("CENTER", row, "CENTER", -total / 2 + size / 2 + (lineIndex - 1) * (size + spacing), y)
    end
  end

  local parent = row.GetParent and row:GetParent() or nil
  if not parent then return end
  local state = parentStates[parent] or {}
  parentStates[parent] = state
  state.mainRow = row
  state.mainIconSize = size
  state.wrapGap = WRAP_GAP
  state.wrapped = overflowCount > 0
  row.__ruiMainBarWrapped = state.wrapped
  row.__ruiMainBarFirstLineCount = firstCount
  row.__ruiMainBarOverflowCount = overflowCount
  EnsureDriver(parent, state)
  ApplyUtilityOffset(state)
end

function W:BuildSpellRow(row, definitions, size, spacing, learnedCallback, textureCallback)
  local result = OriginalBuildSpellRow(self, row, definitions, size, spacing, learnedCallback, textureCallback)
  size = Number(size, 0)
  spacing = Number(spacing, 1)
  local parent = row and row.GetParent and row:GetParent() or nil

  -- All RetreatUI main action rows use 36-38px icons. Utility rows use 28-32px.
  if size >= MAIN_ICON_MINIMUM then
    RepositionMainRow(row, size, spacing)
  elseif parent and parentStates[parent] and parentStates[parent].mainRow then
    local state = parentStates[parent]
    state.utilityRow = row
    local current = ReadAnchor(row)
    if current and not SameAnchor(state.lastAppliedUtilityAnchor,
        current.point, current.relativeTo, current.relativePoint, current.x, current.y) then
      state.baseUtilityAnchor = current
    end
    EnsureDriver(parent, state)
    ApplyUtilityOffset(state)
  end

  return result
end

RUI._mainBarWrapInstalled = true
