local RUI = RetreatUI
if not RUI then return end

-- Screenshot-approved Witch Doctor Totem Bar placement.
-- The Totem Bar sits immediately above the left edge of RetreatUI's primary
-- resource bar: Totem BOTTOMRIGHT -> Power TOPLEFT, with a two-pixel gap.
-- This is a one-time migration so users can still move the bar afterwards.
local PLACEMENT_REVISION = 2026080602
local retryFrame

local function IsFrame(value)
  local kind = type(value)
  if kind ~= "table" and kind ~= "userdata" then return false end
  return type(value.GetObjectType) == "function"
    and type(value.GetCenter) == "function"
    and type(value.SetPoint) == "function"
end

local function ElvUIEngine()
  if not ElvUI then return nil end
  local ok, engine = pcall(function() return unpack(ElvUI) end)
  return ok and engine or nil
end

local function IsWitchDoctor()
  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
  if type(RUI.NormalizeClassName) == "function" then
    className = RUI:NormalizeClassName(className) or className
  end
  return className == "Witch Doctor"
end

local function ResolveBar()
  if IsFrame(_G.ElvUI_BarTotem) then return _G.ElvUI_BarTotem end

  local child = _G.MultiCastActionBarFrame
  if IsFrame(child) and type(child.GetParent) == "function" then
    local ok, parent = pcall(child.GetParent, child)
    if ok and IsFrame(parent) and parent ~= UIParent then return parent end
  end

  for _, name in ipairs({"ElvUI_TotemBar", "ElvUI_TotemBarHolder", "ElvUITotemBar", "TotemBar"}) do
    if IsFrame(_G[name]) then return _G[name] end
  end
  return nil
end

local function ResolveCreatedMover(E, frameName, dbKey)
  local frame = _G[frameName]
  if IsFrame(frame) then return frame end
  local created = E and E.CreatedMovers
  if type(created) == "table" then
    frame = created[frameName] or created[dbKey]
    if IsFrame(frame) then return frame end
  end
  return nil
end

local function BarUsesMover(bar, mover)
  if not bar or not mover or type(bar.GetNumPoints) ~= "function" or type(bar.GetPoint) ~= "function" then
    return false
  end
  for index = 1, tonumber(bar:GetNumPoints()) or 0 do
    local ok, _, relativeTo = pcall(bar.GetPoint, bar, index)
    if ok and relativeTo == mover then return true end
  end
  return false
end

local function ResolveMover(E, bar)
  local ascensionMover = ResolveCreatedMover(E, "ElvBar_TotemMover", "ElvBar_Totem")
  local normalMover = ResolveCreatedMover(E, "TotemBarMover", "TotemBarMover")

  if ascensionMover and BarUsesMover(bar, ascensionMover) then
    return ascensionMover, "ElvBar_Totem"
  end
  if normalMover and BarUsesMover(bar, normalMover) then
    return normalMover, "TotemBarMover"
  end
  if ascensionMover then return ascensionMover, "ElvBar_Totem" end
  if normalMover then return normalMover, "TotemBarMover" end
  return nil, nil
end

local function PositionString(frame)
  local x, y = frame:GetCenter()
  local parent = _G.ElvUIParent or UIParent
  local parentX, parentY = parent and parent:GetCenter()
  if not x or not y or not parentX or not parentY then return nil end
  return string.format(
    "CENTER,ElvUIParent,CENTER,%d,%d",
    math.floor(x - parentX + 0.5),
    math.floor(y - parentY + 0.5)
  )
end

local function SavedData()
  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.totemBar = db.integrations.totemBar or {}
  return db.integrations.totemBar
end

local function ApplyReferencePlacement()
  if not IsWitchDoctor() then return true end
  if InCombatLockdown and InCombatLockdown() then return false end

  local saved = SavedData()
  if tonumber(saved.referencePlacementRevision) == PLACEMENT_REVISION then return true end

  local E = ElvUIEngine()
  local power = type(RUI.GetPrimaryPowerFrame) == "function" and RUI:GetPrimaryPowerFrame()
    or _G.RetreatUIPrimaryPowerBar
  local bar = ResolveBar()
  local mover, moverKey = ResolveMover(E, bar)

  if not E or not E.db or not IsFrame(power) or not IsFrame(bar) or not IsFrame(mover) then
    return false
  end
  if type(power.IsShown) == "function" and not power:IsShown() then return false end

  local width = type(bar.GetWidth) == "function" and tonumber(bar:GetWidth()) or nil
  local height = type(bar.GetHeight) == "function" and tonumber(bar:GetHeight()) or nil
  if width and height and width > 1 and height > 1 and type(mover.SetSize) == "function" then
    mover:SetSize(width, height)
  end

  -- Exact approved relationship from the supplied screenshot.
  mover:ClearAllPoints()
  mover:SetPoint("BOTTOMRIGHT", power, "TOPLEFT", -2, 2)

  bar:ClearAllPoints()
  bar:SetPoint("CENTER", mover, "CENTER", 0, 0)

  local position = PositionString(mover)
  if not position then return false end

  E.db.movers = E.db.movers or {}
  E.db.movers[moverKey] = position
  if moverKey == "ElvBar_Totem" then
    E.db.movers.TotemBarMover = nil
  else
    E.db.movers.ElvBar_Totem = nil
  end

  if ElvDB and ElvDB.profiles and ElvDB.profiles.RetreatUI then
    local profile = ElvDB.profiles.RetreatUI
    profile.movers = profile.movers or {}
    profile.movers[moverKey] = position
    if moverKey == "ElvBar_Totem" then
      profile.movers.TotemBarMover = nil
    else
      profile.movers.ElvBar_Totem = nil
    end
  end

  saved.elvMover = position
  saved.moverKey = moverKey
  saved.referencePlacementRevision = PLACEMENT_REVISION
  saved.version = RUI.version

  if type(E.UpdateMoverPositions) == "function" then pcall(E.UpdateMoverPositions, E) end

  -- ElvUI may rebuild the visible owner while applying mover positions.
  bar = ResolveBar() or bar
  if IsFrame(bar) then
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", mover, "CENTER", 0, 0)
  end
  return true
end

local function StartPlacementRetry()
  if retryFrame then
    retryFrame:Show()
    return
  end

  retryFrame = CreateFrame("Frame")
  local elapsed = 0
  retryFrame:SetScript("OnUpdate", function(self, delta)
    elapsed = elapsed + delta
    if elapsed < 0.35 then return end
    elapsed = 0
    if ApplyReferencePlacement() then self:Hide() end
  end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", StartPlacementRetry)

local originalInitialize = RUI.InitializeTotemBarMover
if type(originalInitialize) == "function" then
  function RUI:InitializeTotemBarMover(...)
    local results = {originalInitialize(self, ...)}
    StartPlacementRetry()
    return unpack(results)
  end
end
