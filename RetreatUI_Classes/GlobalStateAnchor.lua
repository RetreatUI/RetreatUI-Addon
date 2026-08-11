local RUI = RetreatUI
if not RUI or type(RUI.CreateClassStateTracker) ~= "function" then return end

-- One authoritative CoA class-state lane for every class/spec.
--
-- The state lane is anchored to the ACTUAL rendered right edge of the trinket
-- tracker. No theoretical icon count, screen X/Y, class offset or resource-bar
-- calculation is allowed here. Native RetreatUI trinkets and the WeakAuras
-- trinket group are both supported; whichever visible rendered frame ends
-- furthest to the right becomes the source.
--
-- State icons are bottom-aligned with the trinkets. A 38x38 state icon therefore
-- grows upward from the 30x30 trinket row and cannot extend down into the resource
-- bar. Every class and spec uses this exact same rule.
local W = RUI.HUDWidgets
local unpack = unpack or table.unpack
local anchor = _G.RetreatUIClassStateAnchor
if not anchor then
  anchor = CreateFrame("Frame", "RetreatUIClassStateAnchor", UIParent)
  anchor:SetSize(1, 1)
end

local GENERAL_TRINKETS = "RetreatUI - General — Trinkets"
local TRINKET_SLOT_13 = GENERAL_TRINKETS .. " — Slot 13"
local TRINKET_SLOT_14 = GENERAL_TRINKETS .. " — Slot 14"

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

local function FrameRight(frame)
  if not FrameVisible(frame) or type(frame.GetRight) ~= "function" then return nil end
  local ok, value = pcall(frame.GetRight, frame)
  value = ok and tonumber(value) or nil
  return value
end

local function StateSize(value)
  local layout = RUI.layout and RUI.layout.stanceTracker
  return math.max(18, Number(value, Number(layout and layout.size, 38)))
end

local function StateGap(value)
  local layout = RUI.layout and RUI.layout.stanceTracker
  return math.max(0, Number(value, Number(layout and layout.gap, 6)))
end

local function AddCandidate(candidates, frame, name)
  local right = FrameRight(frame)
  if right then
    candidates[#candidates + 1] = {frame=frame, name=name, right=right}
  end
end

local function RenderedTrinketSource()
  local candidates = {}

  -- Native RetreatUI tracker.
  AddCandidate(candidates, _G.RetreatUITrinketTracker, "RetreatUITrinketTracker")

  -- WeakAuras tracker. Use leaf regions first because their visible footprint is
  -- the real on-screen result; the group frame is only a fallback.
  if WeakAuras and type(WeakAuras.GetRegion) == "function" then
    AddCandidate(candidates, WeakAuras.GetRegion(TRINKET_SLOT_13), TRINKET_SLOT_13)
    AddCandidate(candidates, WeakAuras.GetRegion(TRINKET_SLOT_14), TRINKET_SLOT_14)
    AddCandidate(candidates, WeakAuras.GetRegion(GENERAL_TRINKETS), GENERAL_TRINKETS)
  end

  local best
  for _, candidate in ipairs(candidates) do
    if not best or candidate.right > best.right then best = candidate end
  end
  return best and best.frame or nil, best and best.name or nil
end

local function MatchTrinketLayer(frame)
  if not UsableFrame(frame) then return end
  local source = select(1, RenderedTrinketSource())
  if source and type(source.GetFrameLevel) == "function" and type(frame.SetFrameLevel) == "function" then
    local ok, level = pcall(source.GetFrameLevel, source)
    if ok and tonumber(level) then pcall(frame.SetFrameLevel, frame, tonumber(level) + 1) end
  end
end

function RUI:PositionClassStateAnchor()
  if not anchor then return false end
  anchor:ClearAllPoints()

  local source, sourceName = RenderedTrinketSource()
  if source then
    anchor:SetPoint("BOTTOMRIGHT", source, "BOTTOMRIGHT", 0, 0)
    anchor:Show()
    anchor.source = sourceName
    anchor.resolved = true
    return true
  end

  -- Never guess. Until the real trinket region exists, keep the state lane
  -- safely off-screen. Login/equipment/WA refresh retries move it immediately
  -- once the actual rendered source is available.
  anchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", -1000, -1000)
  anchor:Hide()
  anchor.source = "pending rendered trinkets"
  anchor.resolved = false
  return false
end

local function ForceLabelAbove(frame, text, size)
  if not UsableFrame(frame) or not text or type(text.ClearAllPoints) ~= "function" then return end
  text:ClearAllPoints()
  text:SetPoint("BOTTOM", frame, "TOP", 0, 3)
  if type(text.SetJustifyH) == "function" then text:SetJustifyH("CENTER") end
  if type(text.SetWidth) == "function" then text:SetWidth(math.max(StateSize(size), 48)) end
  if type(text.SetWordWrap) == "function" then text:SetWordWrap(false) end
end

function RUI:ReflowClassStateTrackers()
  self:PositionClassStateAnchor()
  local cursor = StateGap()

  for _, frame in ipairs(legacyTrackers) do
    if FrameVisible(frame) then
      local size = StateSize(frame.ruiGlobalStateSize)
      local gap = StateGap(frame.ruiGlobalStateGap)
      frame:ClearAllPoints()
      frame:SetSize(size, size)
      frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", cursor, 0)
      if frame.icon then
        frame.icon:ClearAllPoints()
        frame.icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
      end
      ForceLabelAbove(frame.icon or frame, frame.nameText, size)
      MatchTrinketLayer(frame)
      cursor = cursor + size + gap
    end
  end

  for _, tracker in ipairs(classTrackers) do
    if type(tracker) == "table" and FrameVisible(tracker.parent) then
      local size = StateSize(tracker.ruiGlobalStateSize or (tracker.options and tracker.options.size))
      local gap = StateGap(tracker.ruiGlobalStateGap or (tracker.options and tracker.options.gap))
      for _, frame in ipairs(tracker.frames or {}) do
        if FrameVisible(frame) then
          frame:ClearAllPoints()
          frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", cursor, 0)
          ForceLabelAbove(frame, frame.stateText, size)
          MatchTrinketLayer(frame)
          cursor = cursor + size + gap
        end
      end
    end
  end

  anchor.usedWidth = math.max(0, cursor - StateGap())
  return anchor.resolved == true
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
      ForceLabelAbove(frame.icon or frame, frame.nameText, size)
      RegisterLegacyTracker(frame, options)
    end
    return frame
  end

  if type(W.SetFormTracker) == "function" then
    local originalSetFormTracker = W.SetFormTracker
    function W:SetFormTracker(frame, ...)
      local results = {originalSetFormTracker(self, frame, ...)}
      RUI:ReflowClassStateTrackers()
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
  tracker.ruiGlobalStateYOffset = 0

  local originalUpdate = tracker.Update
  if type(originalUpdate) == "function" then
    tracker.Update = function(object, ...)
      local results = {originalUpdate(object, ...)}
      RUI:ReflowClassStateTrackers()
      return unpack(results)
    end
  end

  local originalUpdateTimers = tracker.UpdateTimers
  if type(originalUpdateTimers) == "function" then
    tracker.UpdateTimers = function(object, ...)
      local results = {originalUpdateTimers(object, ...)}
      RUI:ReflowClassStateTrackers()
      return unpack(results)
    end
  end

  local originalHide = tracker.Hide
  if type(originalHide) == "function" then
    tracker.Hide = function(object, ...)
      local results = {originalHide(object, ...)}
      RUI:ReflowClassStateTrackers()
      return unpack(results)
    end
  end

  local originalPosition = tracker.Position
  if type(originalPosition) == "function" then
    tracker.Position = function(object, ...)
      local results = {originalPosition(object, ...)}
      ScheduleReflow()
      return unpack(results)
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
  configured.x = size / 2 + gap
  configured.y = size / 2
  configured.fallbackX = nil
  configured.fallbackY = nil
  configured.globalYOffset = 0

  self:PositionClassStateAnchor()
  local tracker = originalCreateClassStateTracker(self, parent, className, configured)
  return RegisterClassTracker(tracker, size, gap)
end

local originalRefreshTrinketTracker = RUI.RefreshTrinketTracker
if type(originalRefreshTrinketTracker) == "function" then
  function RUI:RefreshTrinketTracker(...)
    local results = {originalRefreshTrinketTracker(self, ...)}
    RUI:ReflowClassStateTrackers()
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
    for _, delay in ipairs({0.05, 0.15, 0.50, 1.50}) do
      RUI:After(delay, function() RUI:ReflowClassStateTrackers() end)
    end
  end
end)

RUI:PositionClassStateAnchor()
RUI._globalClassStateAnchorLoaded = true
RUI._globalClassStateAnchorRevision = 5
