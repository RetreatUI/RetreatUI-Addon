local RUI = RetreatUI
if not RUI then return end

-- Final CoA stance/state placement contract.
--
-- One rule applies to every class and every spec:
--   * the two 30x30 trinkets define a 63x30 lane above ElvUF_Player
--   * every 38x38 stance/form/state group starts exactly 6px to its right
--   * the BOTTOM edge of the 38x38 state icons is aligned with the BOTTOM edge
--     of the trinket lane, so the taller state icons grow upward instead of down
--     into the primary resource bar
--   * no class/spec-specific X/Y offsets are accepted
--
-- Historical beta.9/beta.10/beta.12 geometry wrappers remain in the package for
-- upgrade compatibility, but this file loads last and is the only authoritative
-- runtime geometry/validation layer.

local GENERAL_ROOT = "RetreatUI - General"
local GENERAL_TRINKETS = GENERAL_ROOT .. " — Trinkets"
local GENERAL_PROCS = GENERAL_ROOT .. " — Buffs & Procs"
local GENERAL_RACIALS = GENERAL_ROOT .. " — Racials"

local PLAYER_FRAME = "ElvUF_Player"
local LANE_FRAME = "RetreatUIWeakAuraTrinketLane"
local TRINKET_ICON = 30
local TRINKET_SPACING = 3
local TRINKET_COUNT = 2
local LANE_WIDTH = TRINKET_ICON * TRINKET_COUNT + TRINKET_SPACING * (TRINKET_COUNT - 1)
local LANE_HEIGHT = TRINKET_ICON
local LANE_X, LANE_Y = -17, 1

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

function RUI:EnsureWeakAuraTrinketLane()
  if not lane then lane = _G[LANE_FRAME] end
  if not lane and type(CreateFrame) == "function" then
    lane = CreateFrame("Frame", LANE_FRAME, UIParent)
  end
  if not lane then return false end

  lane:SetSize(LANE_WIDTH, LANE_HEIGHT)
  lane:ClearAllPoints()
  local player = _G[PLAYER_FRAME]
  if player and type(player.SetPoint) == "function" and type(player.GetWidth) == "function" then
    lane:SetPoint("BOTTOMRIGHT", player, "TOPRIGHT", LANE_X, LANE_Y)
    lane:Show()
    lane.ruiSource = PLAYER_FRAME
    return true
  end

  lane:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  lane:Hide()
  lane.ruiSource = "pending"
  return false
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

  packageData.finalStanceLane = {
    frame = LANE_FRAME,
    laneWidth = LANE_WIDTH,
    laneHeight = LANE_HEIGHT,
    laneX = LANE_X,
    laneY = LANE_Y,
    stateIcon = STATE_ICON,
    stateGap = STATE_GAP,
    anchorPoint = STATE_ANCHOR_POINT,
    selfPoint = STATE_SELF_POINT,
    x = STATE_X,
    y = STATE_Y,
    allClasses = true,
    allSpecs = true,
  }
  return true
end

local previousBuildWeakAuraHUDPackage = RUI.BuildWeakAuraHUDPackage
if type(previousBuildWeakAuraHUDPackage) == "function" then
  function RUI:BuildWeakAuraHUDPackage(className)
    self:EnsureWeakAuraTrinketLane()
    local packageData, buildError = previousBuildWeakAuraHUDPackage(self, className)
    if type(packageData) ~= "table" then return packageData, buildError end
    if not ApplyFinalStateGeometry(packageData) then
      return nil, "Class State WeakAura group is missing from the final trinket lane"
    end
    return packageData, buildError
  end
end

local function CloseEnough(left, right)
  return math.abs(Number(left, 99999) - Number(right, -99999)) <= 0.01
end

local function ValidateLaneFrame()
  local frame = _G[LANE_FRAME]
  local player = _G[PLAYER_FRAME]
  if not frame or not player then return false, "RetreatUI trinket lane frame is unavailable" end
  if not CloseEnough(frame:GetWidth(), LANE_WIDTH) or not CloseEnough(frame:GetHeight(), LANE_HEIGHT) then
    return false, "RetreatUI trinket lane must be exactly 63x30"
  end
  if type(frame.GetPoint) == "function" then
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if point ~= "BOTTOMRIGHT" or relativeTo ~= player or relativePoint ~= "TOPRIGHT"
      or not CloseEnough(x, LANE_X) or not CloseEnough(y, LANE_Y) then
      return false, "RetreatUI trinket lane is not locked to ElvUF_Player"
    end
  end
  return true
end

-- Deliberately do NOT call the older validation chain here. beta.10 validated a
-- retired SCREEN-centred state lane and is the exact source of the Bloodmage
-- "global center lane" failure. This validator supersedes all historical stance
-- geometry checks while retaining the important package/ownership checks.
function RUI:ValidateWeakAuraHUD(className, packageData)
  if not WeakAuras or type(WeakAuras.GetData) ~= "function" then
    return false, "WeakAuras is not loaded"
  end
  className = CurrentClass(self, className)
  packageData = packageData or self:BuildWeakAuraHUDPackage(className)
  if type(packageData) ~= "table" then return false, "WeakAura package could not be built" end

  self:EnsureWeakAuraTrinketLane()
  local laneOK, laneError = ValidateLaneFrame()
  if not laneOK then return false, laneError end

  local expected = packageData.expected or {}
  for _, id in ipairs({expected.general or GENERAL_ROOT, expected.trinkets or GENERAL_TRINKETS, expected.procs or GENERAL_PROCS}) do
    if not id or not WeakAuras.GetData(id) then return false, tostring(id or "General WeakAura") .. " is missing" end
  end

  for _, key in ipairs({"resource", "main", "utility", "state"}) do
    local id = packageData.classGroups and packageData.classGroups[key]
    if not id or not WeakAuras.GetData(id) then return false, "Class " .. key .. " WeakAura group is missing" end
  end

  local trinkets = WeakAuras.GetData(expected.trinkets or GENERAL_TRINKETS)
  if not trinkets or trinkets.anchorFrameType ~= "SELECTFRAME"
    or trinkets.anchorFrameFrame ~= PLAYER_FRAME
    or trinkets.anchorPoint ~= "TOPRIGHT"
    or trinkets.selfPoint ~= "BOTTOMRIGHT"
    or not CloseEnough(trinkets.xOffset, LANE_X)
    or not CloseEnough(trinkets.yOffset, LANE_Y) then
    return false, "General trinket WeakAura is not on the locked CoA trinket lane"
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
    return false, "State/Form group must start 6px right of the trinkets with bottom edges aligned"
  end

  for _, childID in ipairs(state.controlledChildren or {}) do
    local child = WeakAuras.GetData(childID)
    if not child
      or not CloseEnough(child.width, STATE_ICON)
      or not CloseEnough(child.height, STATE_ICON)
      or not CloseEnough(child.xOffset, 0)
      or not CloseEnough(child.yOffset, 0) then
      return false, "Every State/Form icon must be 38x38 with no per-class offset"
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
    return false, "Target debuffs must be owned by ElvUI, not WeakAuras"
  end

  return true, tostring(className) .. " WeakAura HUD verified on the final trinket/stance lane"
end

local previousInstallWeakAuraHUD = RUI.InstallWeakAuraHUD
if type(previousInstallWeakAuraHUD) == "function" then
  function RUI:InstallWeakAuraHUD(className, force)
    self:EnsureWeakAuraTrinketLane()
    return previousInstallWeakAuraHUD(self, className, force)
  end
end

local driver = CreateFrame("Frame", "RetreatUIWeakAuraTrinketLaneDriver")
for _, eventName in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do
  pcall(driver.RegisterEvent, driver, eventName)
end
driver:SetScript("OnEvent", function()
  RUI:EnsureWeakAuraTrinketLane()
  if RUI.After then
    for _, delay in ipairs({0.10, 0.50, 1.50}) do
      RUI:After(delay, function() RUI:EnsureWeakAuraTrinketLane() end)
    end
  end
end)

RUI:EnsureWeakAuraTrinketLane()
RUI._weakAuraBeta15StanceLaneLoaded = true
RUI._weakAuraBeta15StanceLaneRevision = 1
