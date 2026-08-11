local RUI = RetreatUI
if not RUI then return end

-- Final CoA stance/state placement contract.
--
-- There are NO guessed widths or class/spec offsets in this layer.
-- WeakAuras.GetRegion(id) is used to anchor the state lane to the ACTUAL rendered
-- right edge of the visible trinket regions. The named lane frame only exists so
-- the State dynamic group can use WeakAuras' SELECTFRAME anchor mode.
--
-- One rule applies to every CoA class and spec:
--   rendered trinket right edge -> 6px gap -> 38x38 state/form/stance icons
--
-- State labels are constrained to the icon width and elided instead of being
-- allowed to spill left over the trinkets or right over adjacent state icons.

local GENERAL_ROOT = "RetreatUI - General"
local GENERAL_TRINKETS = GENERAL_ROOT .. " — Trinkets"
local GENERAL_PROCS = GENERAL_ROOT .. " — Buffs & Procs"
local GENERAL_RACIALS = GENERAL_ROOT .. " — Racials"
local TRINKET_SLOT_13 = GENERAL_TRINKETS .. " — Slot 13"
local TRINKET_SLOT_14 = GENERAL_TRINKETS .. " — Slot 14"

local LANE_FRAME = "RetreatUIWeakAuraTrinketLane"
local STATE_ICON = 38
local STATE_GAP = 6
local STATE_ANCHOR_POINT = "BOTTOMRIGHT"
local STATE_SELF_POINT = "BOTTOMLEFT"
local STATE_X, STATE_Y = STATE_GAP, 0

local MAIN_X, MAIN_Y = 0, -183
local UTILITY_X, UTILITY_Y = 0, -224

local lane

local function Number(value, fallback)
  value = tonumber(value)
  if value == nil then return fallback end
  return value
end

local function CurrentClass(self, className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  if self.NormalizeClassName then className = self:NormalizeClassName(className) or className end
  return className
end

local function FindByID(list, id)
  for _, item in ipairs(list or {}) do
    if type(item) == "table" and item.id == id then return item end
  end
end

local function PackageGroup(packageData, id)
  if not id then return nil end
  return FindByID(packageData and packageData.groups, id)
    or FindByID(packageData and packageData.roots, id)
end

local function RegionVisible(region)
  if not region or type(region.GetRight) ~= "function" or type(region.GetBottom) ~= "function" then return false end
  if type(region.IsVisible) == "function" then
    local ok, visible = pcall(region.IsVisible, region)
    if ok then return visible == true or visible == 1 end
  end
  if type(region.IsShown) == "function" then
    local ok, shown = pcall(region.IsShown, region)
    if ok then return shown == true or shown == 1 end
  end
  return true
end

local function RegionRight(region)
  if not RegionVisible(region) then return nil end
  local ok, right = pcall(region.GetRight, region)
  right = ok and tonumber(right) or nil
  return right
end

local function RenderedTrinketEdge()
  if not WeakAuras or type(WeakAuras.GetRegion) ~= "function" then return nil end

  local bestRegion, bestID, bestRight
  for _, id in ipairs({TRINKET_SLOT_13, TRINKET_SLOT_14}) do
    local region = WeakAuras.GetRegion(id)
    local right = RegionRight(region)
    if right and (not bestRight or right > bestRight) then
      bestRegion, bestID, bestRight = region, id, right
    end
  end

  -- DynamicGroup itself is the fallback, but still uses the rendered frame.
  -- We never reconstruct its width from icon sizes or offsets.
  if not bestRegion then
    local group = WeakAuras.GetRegion(GENERAL_TRINKETS)
    local right = RegionRight(group)
    if right then bestRegion, bestID, bestRight = group, GENERAL_TRINKETS, right end
  end

  return bestRegion, bestID, bestRight
end

function RUI:EnsureWeakAuraTrinketLane()
  if not lane then lane = _G[LANE_FRAME] end
  if not lane and type(CreateFrame) == "function" then
    lane = CreateFrame("Frame", LANE_FRAME, UIParent)
  end
  if not lane then return false end

  lane:SetSize(1, 1)
  lane:ClearAllPoints()

  local renderedRegion, sourceID = RenderedTrinketEdge()
  if renderedRegion then
    -- This is the only authoritative stance anchor: the ACTUAL rendered right
    -- edge of the right-most visible trinket region.
    lane:SetPoint("BOTTOMRIGHT", renderedRegion, "BOTTOMRIGHT", 0, 0)
    lane:Show()
    lane.ruiSource = sourceID
    lane.ruiResolved = true
    return true
  end

  -- Never fall back to guessed HUD coordinates. Keep the anchor safely offscreen
  -- until WeakAuras has created the real trinket regions, then the retry driver
  -- moves it into place.
  lane:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", -1000, -1000)
  lane:Hide()
  lane.ruiSource = "pending-rendered-trinkets"
  lane.ruiResolved = false
  return false
end

local function LockStateLabel(display)
  if type(display) ~= "table" then return end
  for _, subRegion in ipairs(display.subRegions or {}) do
    if type(subRegion) == "table" and subRegion.type == "subtext" and subRegion.text_text == "%n" then
      subRegion.text_selfPoint = "BOTTOM"
      subRegion.anchor_point = "TOP"
      subRegion.anchorXOffset = 0
      subRegion.anchorYOffset = 3
      subRegion.text_justify = "CENTER"
      subRegion.text_automaticWidth = "Fixed"
      subRegion.text_fixedWidth = STATE_ICON
      subRegion.text_wordWrap = "Elide"
    end
  end
end

local function ApplyFinalStateGeometry(packageData)
  local stateID = packageData and packageData.classGroups and packageData.classGroups.state
  local state = PackageGroup(packageData, stateID)
  if not state then return false end

  state.anchorFrameType = "SELECTFRAME"
  state.anchorFrameFrame = LANE_FRAME
  state.anchorPoint = STATE_ANCHOR_POINT
  state.selfPoint = STATE_SELF_POINT
  state.xOffset = STATE_X
  state.yOffset = STATE_Y
  state.grow = "HORIZONTAL"
  state.align = "LEFT"
  state.space = STATE_GAP
  state.rowSpace = STATE_GAP
  state.columnSpace = STATE_GAP

  local children = {}
  for _, childID in ipairs(state.controlledChildren or {}) do children[childID] = true end
  for _, display in ipairs(packageData.displays or {}) do
    if type(display) == "table" and display.parent == stateID and children[display.id] then
      display.width = STATE_ICON
      display.height = STATE_ICON
      display.xOffset = 0
      display.yOffset = 0
      LockStateLabel(display)
    end
  end

  packageData.finalStanceLane = {
    frame = LANE_FRAME,
    source = "WeakAuras.GetRegion(rendered trinket edge)",
    stateIcon = STATE_ICON,
    stateGap = STATE_GAP,
    anchorPoint = STATE_ANCHOR_POINT,
    selfPoint = STATE_SELF_POINT,
    x = STATE_X,
    y = STATE_Y,
    allClasses = true,
    allSpecs = true,
    guessedWidth = false,
  }
  return true
end

local previousBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(previousBuildWeakAuraHUDPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    local packageData, buildError = previousBuildWeakAuraHUDPackage(self, className)
    if type(packageData) ~= "table" then return packageData, buildError end
    if not ApplyFinalStateGeometry(packageData) then
      return nil, "Class State WeakAura group is missing from the rendered trinket lane"
    end
    return packageData, buildError
  end
end

local function CloseEnough(left, right)
  return math.abs(Number(left, 99999) - Number(right, -99999)) <= 0.01
end

-- Runtime geometry diagnostics are intentionally separate from HUD activation.
-- A temporary WeakAuras layout race must never prevent Bloodmage/KoX/etc. from
-- activating again. This returns real rendered measurements when available.
function RUI:GetWeakAuraStanceLaneDiagnostics(className)
  className = CurrentClass(self, className)
  self:EnsureWeakAuraTrinketLane()

  local trinketRegion, trinketID, trinketRight = RenderedTrinketEdge()
  local stateID = "RetreatUI - " .. tostring(className) .. " — State"
  local stateRegion = WeakAuras and WeakAuras.GetRegion and WeakAuras.GetRegion(stateID) or nil
  local stateLeft, stateBottom, trinketBottom

  if stateRegion and type(stateRegion.GetLeft) == "function" then
    local ok, value = pcall(stateRegion.GetLeft, stateRegion)
    if ok then stateLeft = tonumber(value) end
  end
  if stateRegion and type(stateRegion.GetBottom) == "function" then
    local ok, value = pcall(stateRegion.GetBottom, stateRegion)
    if ok then stateBottom = tonumber(value) end
  end
  if trinketRegion and type(trinketRegion.GetBottom) == "function" then
    local ok, value = pcall(trinketRegion.GetBottom, trinketRegion)
    if ok then trinketBottom = tonumber(value) end
  end

  return {
    className = className,
    sourceID = trinketID,
    resolved = lane and lane.ruiResolved == true or false,
    trinketRight = trinketRight,
    stateLeft = stateLeft,
    renderedGap = trinketRight and stateLeft and (stateLeft - trinketRight) or nil,
    trinketBottom = trinketBottom,
    stateBottom = stateBottom,
  }
end

-- Do NOT call the historical validation chain here. Older beta validators checked
-- retired screen coordinates and previously blocked Bloodmage activation. This
-- validator checks package ownership/config only; rendered placement self-corrects
-- from the live WeakAuras regions and never blocks class activation on timing.
function RUI:ValidateWeakAuraHUD(className, packageData)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" then
    return false, "WeakAuras is not loaded"
  end

  className = CurrentClass(self, className)
  packageData = packageData or self:BuildWeakAuraHUDPackage(className)
  if type(packageData) ~= "table" then return false, "WeakAura package could not be built" end

  local expected = packageData.expected or {}
  for _, id in ipairs({expected.general or GENERAL_ROOT, expected.trinkets or GENERAL_TRINKETS, expected.procs or GENERAL_PROCS}) do
    if not id or not WeakAuras.GetData(id) then return false, tostring(id or "General WeakAura") .. " is missing" end
  end

  for _, key in ipairs({"resource", "main", "utility", "state"}) do
    local id = packageData.classGroups and packageData.classGroups[key]
    if not id or not WeakAuras.GetData(id) then return false, "Class " .. key .. " WeakAura group is missing" end
  end

  local stateID = packageData.classGroups.state
  local state = WeakAuras.GetData(stateID)
  if not state
    or state.anchorFrameType ~= "SELECTFRAME"
    or state.anchorFrameFrame ~= LANE_FRAME
    or state.anchorPoint ~= STATE_ANCHOR_POINT
    or state.selfPoint ~= STATE_SELF_POINT
    or not CloseEnough(state.xOffset, STATE_X)
    or not CloseEnough(state.yOffset, STATE_Y)
    or state.grow ~= "HORIZONTAL"
    or state.align ~= "LEFT"
    or not CloseEnough(state.space, STATE_GAP) then
    return false, "State/Form group is not configured for the rendered trinket edge"
  end

  for _, childID in ipairs(state.controlledChildren or {}) do
    local child = WeakAuras.GetData(childID)
    if not child
      or not CloseEnough(child.width, STATE_ICON)
      or not CloseEnough(child.height, STATE_ICON)
      or not CloseEnough(child.xOffset, 0)
      or not CloseEnough(child.yOffset, 0) then
      return false, "Every State/Form icon must be 38x38 with no class/spec offset"
    end
  end

  local main = WeakAuras.GetData(packageData.classGroups.main)
  local utility = WeakAuras.GetData(packageData.classGroups.utility)
  if not main or not CloseEnough(main.xOffset, MAIN_X) or not CloseEnough(main.yOffset, MAIN_Y) then
    return false, "Main WeakAura row has the wrong HUD position"
  end
  if not utility or not CloseEnough(utility.xOffset, UTILITY_X) or not CloseEnough(utility.yOffset, UTILITY_Y) then
    return false, "Utility WeakAura row has the wrong HUD position"
  end

  local racials = WeakAuras.GetData(GENERAL_RACIALS)
  if not racials or racials.parent ~= GENERAL_ROOT then
    return false, "General Racials WeakAura group is missing"
  end

  local oldTarget = WeakAuras.GetData("RetreatUI - " .. tostring(className) .. " — Target")
  if oldTarget then return false, "Legacy Target WeakAura group is still installed" end
  if packageData.classGroups and packageData.classGroups.target ~= nil then
    return false, "Target debuffs must not be owned by the CoA WeakAura HUD"
  end

  self:EnsureWeakAuraTrinketLane()
  return true, tostring(className) .. " WeakAura HUD verified; stance follows rendered trinket edge"
end

local previousInstallWeakAuraHUD = RUI.InstallWeakAuraHUD
if type(previousInstallWeakAuraHUD) == "function" then
  function RUI:InstallWeakAuraHUD(className, force)
    local ok, message = previousInstallWeakAuraHUD(self, className, force)
    self:EnsureWeakAuraTrinketLane()
    if self.After then
      for _, delay in ipairs({0, 0.05, 0.15, 0.50, 1.50}) do
        self:After(delay, function() self:EnsureWeakAuraTrinketLane() end)
      end
    end
    return ok, message
  end
end

local driver = CreateFrame("Frame", "RetreatUIWeakAuraTrinketLaneDriver")
for _, eventName in ipairs({
  "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED", "UI_SCALE_CHANGED",
  "DISPLAY_SIZE_CHANGED",
}) do
  pcall(driver.RegisterEvent, driver, eventName)
end

driver:SetScript("OnEvent", function(_, _, unit)
  if unit and unit ~= "player" then return end
  RUI:EnsureWeakAuraTrinketLane()
  if RUI.After then
    for _, delay in ipairs({0.05, 0.15, 0.50, 1.50}) do
      RUI:After(delay, function() RUI:EnsureWeakAuraTrinketLane() end)
    end
  end
end)

RUI:EnsureWeakAuraTrinketLane()
RUI._weakAuraBeta15StanceLaneLoaded = true
RUI._weakAuraBeta15StanceLaneRevision = 2
