local RUI = RetreatUI
if not RUI or type(RUI.CreateClassStateTracker) ~= "function" then return end

-- Every class-owned stance, form, aspect, oath, formation and presence uses one
-- shared horizontal lane immediately to the right of RetreatUI's trinkets.
--
-- RetreatUI has two tracker generations:
--   1. HUDWidgets:CreateFormTracker (older class-specific HUDs)
--   2. CreateClassStateTracker (the shared grouped state tracker)
--
-- Both are registered here so a class can never need its own coordinates. Only
-- visible states consume a slot, and every label is forced above its icon.
local W = RUI.HUDWidgets
local unpack = unpack or table.unpack
local anchor = _G.RetreatUIClassStateAnchor
if not anchor then
  anchor = CreateFrame("Frame", "RetreatUIClassStateAnchor", UIParent)
  anchor:SetSize(1, 1)
end

local legacyTrackers = {}
local classTrackers = {}
local legacySeen = setmetatable({}, {__mode="k"})
local classSeen = setmetatable({}, {__mode="k"})
local reflowPending = false

local function Number(value, fallback)
  value = tonumber(value)
  if value == nil then return fallback end
  return value
end

local function UsableFrame(frame)
  local kind = type(frame)
  return (kind == "table" or kind == "userdata")
    and type(frame.SetPoint) == "function"
    and type(frame.GetWidth) == "function"
end

local function FrameVisible(frame)
  if not UsableFrame(frame) then return false end
  if type(frame.IsVisible) == "function" then
    local ok, visible = pcall(frame.IsVisible, frame)
    if ok then return visible == true or visible == 1 end
  end
  if type(frame.IsShown) == "function" then
    local ok, shown = pcall(frame.IsShown, frame)
    if ok then return shown == true or shown == 1 end
  end
  return true
end

local function StateSize(value)
  local layout = RUI.layout and RUI.layout.stanceTracker
  return math.max(18, Number(value, Number(layout and layout.size, 38)))
end

local function StateGap(value)
  local layout = RUI.layout and RUI.layout.stanceTracker
  return math.max(0, Number(value, Number(layout and layout.gap, 6)))
end

local function MatchTrinketLayer(frame)
  if not UsableFrame(frame) then return end
  local trinkets = _G.RetreatUITrinketTracker
  if trinkets and type(trinkets.GetFrameLevel) == "function" and type(frame.SetFrameLevel) == "function" then
    local ok, level = pcall(trinkets.GetFrameLevel, trinkets)
    if ok and tonumber(level) then pcall(frame.SetFrameLevel, frame, tonumber(level) + 1) end
  end
end

function RUI:PositionClassStateAnchor()
  if not anchor then return false end
  anchor:ClearAllPoints()

  local trinkets = _G.RetreatUITrinketTracker
  if UsableFrame(trinkets) then
    anchor:SetPoint("CENTER", trinkets, "RIGHT", 0, 0)
    anchor.source = "RetreatUITrinketTracker"
    return true
  end

  -- Keep the same lane even when the Trinket HUD is disabled or has not been
  -- created yet. This is the centre of the trinket row's expected right edge.
  local player = _G.ElvUF_Player or _G.ElvUF_PlayerMover or _G.PlayerFrame
  if UsableFrame(player) then
    local trinketSize = 30
    anchor:SetPoint("CENTER", player, "TOPRIGHT", 0, 2 + trinketSize / 2)
    anchor.source = "player fallback"
    return true
  end

  local power = RUI.layout and RUI.layout.power or {x=0, y=-152, width=360, height=16}
  local trinketSize = 30
  local trinketWidth = trinketSize * 2 + 3
  local x = Number(power.x, 0) - Number(power.width, 360) / 2 + trinketWidth
  local y = Number(power.y, -152) + Number(power.height, 16) / 2 + trinketSize / 2 + 5
  anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
  anchor.source = "HUD fallback"
  return true
end

local function ForceLabelAbove(frame, text)
  if not UsableFrame(frame) or not text or type(text.ClearAllPoints) ~= "function" then return end
  text:ClearAllPoints()
  text:SetPoint("BOTTOM", frame, "TOP", 0, 3)
  if type(text.SetJustifyH) == "function" then text:SetJustifyH("CENTER") end
end

function RUI:ReflowClassStateTrackers()
  self:PositionClassStateAnchor()
  local cursor = StateGap()

  -- Older form trackers occupy the first visible slots. Their frame is reduced
  -- to the icon footprint so their old 92px container cannot overlap trinkets.
  for _, frame in ipairs(legacyTrackers) do
    if FrameVisible(frame) then
      local size = StateSize(frame.ruiGlobalStateSize)
      local gap = StateGap(frame.ruiGlobalStateGap)
      frame:ClearAllPoints()
      frame:SetSize(size, size)
      frame:SetPoint("LEFT", anchor, "RIGHT", cursor, 0)
      if frame.icon then
        frame.icon:ClearAllPoints()
        frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
      end
      ForceLabelAbove(frame.icon or frame, frame.nameText)
      MatchTrinketLayer(frame)
      cursor = cursor + size + gap
    end
  end

  -- Grouped class-state frames continue directly after any visible legacy form
  -- tracker. Hidden groups consume no space, so the lane always stays compact.
  for _, tracker in ipairs(classTrackers) do
    if type(tracker) == "table" and FrameVisible(tracker.parent) then
      local size = StateSize(tracker.ruiGlobalStateSize or (tracker.options and tracker.options.size))
      local gap = StateGap(tracker.ruiGlobalStateGap or (tracker.options and tracker.options.gap))
      local yOffset = Number(tracker.ruiGlobalStateYOffset, 0)
      for _, frame in ipairs(tracker.frames or {}) do
        if FrameVisible(frame) then
          frame:ClearAllPoints()
          frame:SetPoint("LEFT", anchor, "RIGHT", cursor, yOffset)
          ForceLabelAbove(frame, frame.stateText)
          MatchTrinketLayer(frame)
          cursor = cursor + size + gap
        end
      end
    end
  end

  anchor.usedWidth = math.max(0, cursor - StateGap())
  return true
end

local function ScheduleReflow()
  if reflowPending then return end
  reflowPending = true
  local function Run()
    reflowPending = false
    RUI:ReflowClassStateTrackers()
  end
  if RUI.After then RUI:After(0, Run) else Run() end
end

local function RegisterLegacyTracker(frame, options)
  if not UsableFrame(frame) or legacySeen[frame] then return frame end
  legacySeen[frame] = true
  legacyTrackers[#legacyTrackers + 1] = frame
  frame.usesGlobalStateAnchor = true
  frame.ruiGlobalStateSize = StateSize(options and options.size)
  frame.ruiGlobalStateGap = StateGap(options and options.gap)

  if type(frame.SetScript) == "function" then
    frame:SetScript("OnShow", ScheduleReflow)
    frame:SetScript("OnHide", ScheduleReflow)
  end
  ScheduleReflow()
  return frame
end

-- Bring every old CreateFormTracker user under the same global layout without
-- editing Necromancer or any other class HUD individually.
if W and type(W.CreateFormTracker) == "function" then
  local originalCreateFormTracker = W.CreateFormTracker
  function W:CreateFormTracker(parent, options)
    local frame = originalCreateFormTracker(self, parent, options)
    if frame then
      local size = StateSize(options and options.size)
      frame:SetSize(size, size)
      if frame.icon then
        frame.icon:ClearAllPoints()
        frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
      end
      ForceLabelAbove(frame.icon or frame, frame.nameText)
      RegisterLegacyTracker(frame, options)
    end
    return frame
  end

  if type(W.SetFormTracker) == "function" then
    local originalSetFormTracker = W.SetFormTracker
    function W:SetFormTracker(frame, ...)
      local results = {originalSetFormTracker(self, frame, ...)}
      ScheduleReflow()
      return unpack(results)
    end
  end
end

local function RegisterClassTracker(tracker, size, gap)
  if type(tracker) ~= "table" or classSeen[tracker] then return tracker end
  classSeen[tracker] = true
  classTrackers[#classTrackers + 1] = tracker
  tracker.usesGlobalStateAnchor = true
  tracker.ruiGlobalStateSize = StateSize(size)
  tracker.ruiGlobalStateGap = StateGap(gap)

  local normalizedClass = RUI.NormalizeClassName and RUI:NormalizeClassName(tracker.className) or tracker.className
  local defaultYOffset = normalizedClass == "Guardian" and 10 or 0
  tracker.ruiGlobalStateYOffset = Number(tracker.options and tracker.options.globalYOffset, defaultYOffset)

  for _, methodName in ipairs({"Update", "UpdateTimers", "Hide", "Position"}) do
    local original = tracker[methodName]
    if type(original) == "function" then
      tracker[methodName] = function(object, ...)
        local results = {original(object, ...)}
        ScheduleReflow()
        return unpack(results)
      end
    end
  end
  ScheduleReflow()
  return tracker
end

local originalCreateClassStateTracker = RUI.CreateClassStateTracker
function RUI:CreateClassStateTracker(parent, className, options)
  local configured = {}
  for key, value in pairs(options or {}) do configured[key] = value end

  local size = StateSize(configured.size)
  local gap = StateGap(configured.gap)
  configured.anchor = nil
  configured.anchorFrameName = "RetreatUIClassStateAnchor"
  configured.direction = "right"
  -- These values keep the frame approximately aligned during the original
  -- tracker's own Position pass; the shared reflow is authoritative afterwards.
  configured.x = size / 2 + gap
  configured.y = -(size / 2) + 3
  configured.fallbackX = nil
  configured.fallbackY = nil

  self:PositionClassStateAnchor()
  local tracker = originalCreateClassStateTracker(self, parent, className, configured)
  return RegisterClassTracker(tracker, size, gap)
end

-- The trinket engine can change anchors after login, equipment changes or an
-- ElvUI refresh. Reflow the complete lane immediately after it.
local originalRefreshTrinketTracker = RUI.RefreshTrinketTracker
if type(originalRefreshTrinketTracker) == "function" then
  function RUI:RefreshTrinketTracker(...)
    local results = {originalRefreshTrinketTracker(self, ...)}
    ScheduleReflow()
    return unpack(results)
  end
end

local events = CreateFrame("Frame", "RetreatUIClassStateAnchorDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED", "UNIT_AURA", "UPDATE_SHAPESHIFT_FORM",
  "UPDATE_SHAPESHIFT_FORMS", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, _, unit)
  if unit and unit ~= "player" then return end
  ScheduleReflow()
  if RUI.After then
    for _, delay in ipairs({0.10, 0.50, 1.50}) do
      RUI:After(delay, function() RUI:ReflowClassStateTrackers() end)
    end
  end
end)

RUI:PositionClassStateAnchor()
RUI._globalClassStateAnchorLoaded = true
RUI._globalClassStateAnchorRevision = 3
