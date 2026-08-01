local RUI = RetreatUI
if not RUI or type(RUI.CreateClassStateTracker) ~= "function" then return end

-- Every class-owned stance, form, aspect, oath, formation and presence uses one
-- shared anchor. The anchor follows the right edge of the trinket tracker so a
-- class state can never cover the player frame or collide with the trinkets.
local anchor = _G.RetreatUIClassStateAnchor
if not anchor then
  anchor = CreateFrame("Frame", "RetreatUIClassStateAnchor", UIParent)
  anchor:SetSize(1, 1)
end

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

local function StateSize()
  local layout = RUI.layout and RUI.layout.stanceTracker
  return math.max(18, Number(layout and layout.size, 38))
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

  -- Keep the same row even when the Trinket HUD is disabled or has not been
  -- created yet. This is the position where its right edge would normally be.
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

local originalCreateClassStateTracker = RUI.CreateClassStateTracker
function RUI:CreateClassStateTracker(parent, className, options)
  local configured = {}
  for key, value in pairs(options or {}) do configured[key] = value end

  local size = math.max(18, Number(configured.size, StateSize()))
  local gap = math.max(0, Number(configured.gap,
    RUI.layout and RUI.layout.stanceTracker and RUI.layout.stanceTracker.gap or 6))

  configured.anchor = nil
  configured.anchorFrameName = "RetreatUIClassStateAnchor"
  configured.direction = "right"
  configured.x = size / 2 + gap
  configured.y = -(size / 2)
  configured.fallbackX = nil
  configured.fallbackY = nil

  self:PositionClassStateAnchor()
  local tracker = originalCreateClassStateTracker(self, parent, className, configured)
  if tracker then tracker.usesGlobalStateAnchor = true end
  return tracker
end

-- The trinket engine can change anchors after login, equipment changes or an
-- ElvUI refresh. Reposition the shared class-state anchor immediately after it.
local originalRefreshTrinketTracker = RUI.RefreshTrinketTracker
if type(originalRefreshTrinketTracker) == "function" then
  function RUI:RefreshTrinketTracker(...)
    local results = {originalRefreshTrinketTracker(self, ...)}
    self:PositionClassStateAnchor()
    return unpack(results)
  end
end

local events = CreateFrame("Frame", "RetreatUIClassStateAnchorDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
}) do
  pcall(events.RegisterEvent, events, eventName)
end

events:SetScript("OnEvent", function(_, _, unit)
  if unit and unit ~= "player" then return end
  RUI:PositionClassStateAnchor()
  if RUI.After then
    for _, delay in ipairs({0.10, 0.50, 1.50}) do
      RUI:After(delay, function() RUI:PositionClassStateAnchor() end)
    end
  end
end)

RUI:PositionClassStateAnchor()
RUI._globalClassStateAnchorLoaded = true
