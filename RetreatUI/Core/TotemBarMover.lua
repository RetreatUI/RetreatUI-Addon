local RUI = RetreatUI
if not RUI then return end

local handle
local currentBar
local currentMover
local currentMoverKey
local currentDragTarget
local dragTargetWasShown
local dragTargetAlpha
local refreshFrame

local BAR_NAMES = {
  -- Ascension ElvUI owns the visible totem buttons through this frame.
  -- MultiCastActionBarFrame is only its child and must never be treated as
  -- the movable bar itself.
  "ElvUI_BarTotem",
  "ElvUI_TotemBar",
  "ElvUI_TotemBarHolder",
  "ElvUITotemBar",
  "TotemBar",
  "TotemFrame",
  "MultiCastActionBarFrame",
}

-- Ascension can expose its own Totem Bar mover while ElvUI also registers the
-- normal TotemBarMover. RetreatUI uses one mover only and suppresses the other
-- from Toggle Anchors so the user never sees two independent Totem Bar anchors.
local MOVER_DEFINITIONS = {
  {frameName="ElvBar_TotemMover", dbKey="ElvBar_Totem"},
  {frameName="TotemBarMover", dbKey="TotemBarMover"},
}

local suppressedMovers = {}

local function IsWitchDoctor()
  local className = type(RUI.GetDetectedClass) == "function" and RUI:GetDetectedClass() or nil
  if type(RUI.NormalizeClassName) == "function" then className = RUI:NormalizeClassName(className) or className end
  return className == "Witch Doctor"
end

local function IsFrame(value)
  local valueType = type(value)
  if valueType ~= "table" and valueType ~= "userdata" then return false end
  return type(value.GetObjectType) == "function" and type(value.GetCenter) == "function"
end

local function ElvUIEngine()
  if not ElvUI then return nil end
  local ok, engine = pcall(function() return unpack(ElvUI) end)
  return ok and engine or nil
end

local function FrameName(frame)
  if not frame or type(frame.GetName) ~= "function" then return nil end
  local ok, name = pcall(frame.GetName, frame)
  return ok and name or nil
end

local function IsTotemNamedFrame(frame)
  local name = string.lower(tostring(FrameName(frame) or ""))
  return string.find(name, "bartotem", 1, true)
    or string.find(name, "totembar", 1, true)
end

local function ResolveBar()
  -- In Ascension ElvUI the real movable owner is ElvUI_BarTotem.
  -- The Blizzard MultiCastActionBarFrame is parented to it and is continuously
  -- re-anchored by ElvUI, which is why moving the child produced a detached
  -- empty anchor in beta.4.
  local elvBar = _G.ElvUI_BarTotem
  if IsFrame(elvBar) then return elvBar end

  local multiCast = _G.MultiCastActionBarFrame
  if IsFrame(multiCast) and type(multiCast.GetParent) == "function" then
    local ok, parent = pcall(multiCast.GetParent, multiCast)
    if ok and IsFrame(parent) and parent ~= UIParent and IsTotemNamedFrame(parent) then
      return parent
    end
  end

  for _, name in ipairs(BAR_NAMES) do
    local frame = _G[name]
    if IsFrame(frame) then
      -- Never choose the Blizzard child when its ElvUI owner can be recovered.
      if frame == multiCast and type(frame.GetParent) == "function" then
        local ok, parent = pcall(frame.GetParent, frame)
        if ok and IsFrame(parent) and parent ~= UIParent then return parent end
      end
      return frame
    end
  end

  local best, bestScore
  for name, value in pairs(_G) do
    local lower = type(name) == "string" and string.lower(name) or ""
    if lower ~= ""
      and (string.find(lower, "totembar", 1, true) or string.find(lower, "bartotem", 1, true))
      and not string.find(lower, "mover", 1, true)
      and IsFrame(value) then
      local width = 0
      if type(value.GetWidth) == "function" then
        local ok, result = pcall(value.GetWidth, value)
        width = ok and tonumber(result) or 0
      end
      if width >= 70 then
        local score = width
        if lower == "elvui_bartotem" then score = score + 10000 end
        if multiCast and type(multiCast.GetParent) == "function" then
          local ok, parent = pcall(multiCast.GetParent, multiCast)
          if ok and parent == value then score = score + 5000 end
        end
        if not bestScore or score > bestScore then
          best, bestScore = value, score
        end
      end
    end
  end
  return best
end

local function ResolveMoverFrame(definition)
  local frame = _G[definition.frameName]
  if IsFrame(frame) then return frame end

  local E = ElvUIEngine()
  local created = E and E.CreatedMovers
  if type(created) == "table" then
    frame = created[definition.frameName] or created[definition.dbKey]
    if IsFrame(frame) then return frame end
  end
  return nil
end

local function MoverDefinitionForFrame(frame)
  if not frame then return nil end
  for _, definition in ipairs(MOVER_DEFINITIONS) do
    if ResolveMoverFrame(definition) == frame then return definition end
  end
  return nil
end

local function BarAnchoredToMover(bar, mover)
  if not bar or not mover or type(bar.GetNumPoints) ~= "function" or type(bar.GetPoint) ~= "function" then return false end
  local points = tonumber(bar:GetNumPoints()) or 0
  for index = 1, points do
    local ok, _, relativeTo = pcall(bar.GetPoint, bar, index)
    if ok and relativeTo == mover then return true end
  end
  return false
end

local function ResolveMover(bar)
  -- Preserve the mover already owning the visible bar whenever possible.
  for _, definition in ipairs(MOVER_DEFINITIONS) do
    local mover = ResolveMoverFrame(definition)
    if mover and BarAnchoredToMover(bar, mover) then return mover, definition.dbKey end
  end

  -- RetreatUI/Ascension mover is preferred. The normal ElvUI mover remains a
  -- safe fallback on clients where the Ascension mover has not been created.
  for _, definition in ipairs(MOVER_DEFINITIONS) do
    local mover = ResolveMoverFrame(definition)
    if mover then return mover, definition.dbKey end
  end
  return nil, nil
end

local function PositionString(frame)
  if not frame or not frame.GetCenter then return nil end
  local x, y = frame:GetCenter()
  local parent = _G.ElvUIParent or UIParent
  local parentX, parentY
  if parent and parent.GetCenter then parentX, parentY = parent:GetCenter() end
  if not x or not y or not parentX or not parentY then return nil end
  return string.format("CENTER,ElvUIParent,CENTER,%d,%d", math.floor(x - parentX + 0.5), math.floor(y - parentY + 0.5))
end

local function SavedTotemData()
  local db = RUI:EnsureDB()
  db.integrations = db.integrations or {}
  db.integrations.totemBar = db.integrations.totemBar or {}
  return db.integrations.totemBar
end

local function ClearInactiveMoverKeys(activeKey)
  local E = ElvUIEngine()
  if E and E.db then
    E.db.movers = E.db.movers or {}
    for _, definition in ipairs(MOVER_DEFINITIONS) do
      if definition.dbKey ~= activeKey then E.db.movers[definition.dbKey] = nil end
    end
  end

  if ElvDB and ElvDB.profiles and ElvDB.profiles.RetreatUI then
    local profile = ElvDB.profiles.RetreatUI
    profile.movers = profile.movers or {}
    for _, definition in ipairs(MOVER_DEFINITIONS) do
      if definition.dbKey ~= activeKey then profile.movers[definition.dbKey] = nil end
    end
  end
end

local function RestoreSuppressedMovers()
  for mover in pairs(suppressedMovers) do
    mover._ruiSuppressDuplicateTotemMover = nil
    if type(mover.EnableMouse) == "function" then pcall(mover.EnableMouse, mover, true) end
    suppressedMovers[mover] = nil
  end
end

local function SuppressDuplicateMovers(activeMover, activeKey)
  if not IsWitchDoctor() then
    RestoreSuppressedMovers()
    return
  end

  ClearInactiveMoverKeys(activeKey)
  for _, definition in ipairs(MOVER_DEFINITIONS) do
    local mover = ResolveMoverFrame(definition)
    if mover and mover ~= activeMover then
      mover._ruiSuppressDuplicateTotemMover = true
      suppressedMovers[mover] = true
      if type(mover.EnableMouse) == "function" then pcall(mover.EnableMouse, mover, false) end
      if type(mover.HookScript) == "function" and not mover._ruiTotemDuplicateHooked then
        mover._ruiTotemDuplicateHooked = true
        mover:HookScript("OnShow", function(self)
          if IsWitchDoctor() and self._ruiSuppressDuplicateTotemMover and self ~= currentMover then
            self:Hide()
          end
        end)
      end
      if type(mover.Hide) == "function" then pcall(mover.Hide, mover) end
    elseif mover == activeMover then
      mover._ruiSuppressDuplicateTotemMover = nil
      suppressedMovers[mover] = nil
      if type(mover.EnableMouse) == "function" then pcall(mover.EnableMouse, mover, true) end
    end
  end
end

local function SaveNativePosition(frame)
  if not frame or not frame.GetPoint then return end
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  local saved = SavedTotemData()
  saved.native = {
    point=point or "CENTER",
    relativePoint=relativePoint or "CENTER",
    x=tonumber(x) or 0,
    y=tonumber(y) or 0,
  }
  saved.version = RUI.version
end

local function SaveElvUIPosition(frame)
  local position = PositionString(frame)
  if not position then return false end
  local definition = MoverDefinitionForFrame(frame)
  local moverKey = definition and definition.dbKey or currentMoverKey or "ElvBar_Totem"
  local E = ElvUIEngine()
  if not E or not E.db then return false end

  E.db.movers = E.db.movers or {}
  E.db.movers[moverKey] = position
  ClearInactiveMoverKeys(moverKey)

  if ElvDB and ElvDB.profiles and ElvDB.profiles.RetreatUI then
    local profile = ElvDB.profiles.RetreatUI
    profile.movers = profile.movers or {}
    profile.movers[moverKey] = position
  end

  local saved = SavedTotemData()
  saved.elvMover = position
  saved.moverKey = moverKey
  saved.version = RUI.version
  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  return true
end

function RUI:GetTotemBarMoverPosition()
  local saved = SavedTotemData()
  local E = ElvUIEngine()
  local movers = E and E.db and E.db.movers
  local key = saved.moverKey

  if key and saved.elvMover and saved.elvMover ~= "" then return saved.elvMover, key end
  if movers then
    if movers.ElvBar_Totem then return movers.ElvBar_Totem, "ElvBar_Totem" end
    if movers.TotemBarMover then return movers.TotemBarMover, "TotemBarMover" end
  end
  if saved.elvMover and saved.elvMover ~= "" then return saved.elvMover, "ElvBar_Totem" end
  return nil, nil
end

local function ApplySavedPosition(mover, moverKey, bar)
  local saved = SavedTotemData()
  local E = ElvUIEngine()
  if mover and moverKey and E and E.db then
    local position = saved.elvMover
    if not position or position == "" then
      local movers = E.db.movers or {}
      position = movers[moverKey] or movers.ElvBar_Totem or movers.TotemBarMover
    end
    if position and position ~= "" then
      E.db.movers = E.db.movers or {}
      E.db.movers[moverKey] = position
      saved.elvMover = position
      saved.moverKey = moverKey
      ClearInactiveMoverKeys(moverKey)
      if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
      return
    end
  end

  if bar and type(saved.native) == "table" and not (InCombatLockdown and InCombatLockdown()) then
    pcall(bar.ClearAllPoints, bar)
    pcall(bar.SetPoint, bar, saved.native.point or "CENTER", UIParent, saved.native.relativePoint or "CENTER", saved.native.x or 0, saved.native.y or 0)
  end
end

local function RestoreVisibleTotemChild(bar)
  local child = _G.MultiCastActionBarFrame
  if not IsFrame(child) or child == bar or not bar then return end
  if InCombatLockdown and InCombatLockdown() then return end

  -- Repair the detached state left by beta.4, where the Blizzard child could
  -- be anchored directly to the mover instead of to ElvUI_BarTotem.
  if type(child.GetParent) == "function" then
    local ok, parent = pcall(child.GetParent, child)
    if ok and parent ~= bar and type(child.SetParent) == "function" then
      pcall(child.SetParent, child, bar)
    end
  end

  local correctlyAnchored = false
  if type(child.GetNumPoints) == "function" and type(child.GetPoint) == "function" then
    local points = tonumber(child:GetNumPoints()) or 0
    for index = 1, points do
      local ok, point, relativeTo, relativePoint, x, y = pcall(child.GetPoint, child, index)
      if ok and relativeTo == bar and point == "BOTTOMLEFT" and relativePoint == "BOTTOMLEFT"
        and math.abs(tonumber(x) or 0) < 0.01 and math.abs(tonumber(y) or 0) < 0.01 then
        correctlyAnchored = true
        break
      end
    end
  end

  if not correctlyAnchored then
    pcall(child.ClearAllPoints, child)
    pcall(child.SetPoint, child, "BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
  end
end

local function LinkBarToMover(bar, mover)
  if not bar or not mover or bar == mover then return false end
  if InCombatLockdown and InCombatLockdown() then return false end

  local width = type(bar.GetWidth) == "function" and tonumber(bar:GetWidth()) or nil
  local height = type(bar.GetHeight) == "function" and tonumber(bar:GetHeight()) or nil
  if width and height and width > 1 and height > 1 and type(mover.SetSize) == "function" then
    pcall(mover.SetSize, mover, width, height)
  end

  if not BarAnchoredToMover(bar, mover) then
    pcall(bar.ClearAllPoints, bar)
    pcall(bar.SetPoint, bar, "CENTER", mover, "CENTER", 0, 0)
  end

  RestoreVisibleTotemChild(bar)
  bar._ruiLinkedTotemMover = mover
  return true
end

local function RestoreDragTargetVisibility()
  if not currentDragTarget then return end
  if type(currentDragTarget.SetAlpha) == "function" and dragTargetAlpha ~= nil then
    pcall(currentDragTarget.SetAlpha, currentDragTarget, dragTargetAlpha)
  end
  if dragTargetWasShown == false and type(currentDragTarget.Hide) == "function" then
    pcall(currentDragTarget.Hide, currentDragTarget)
  end
  dragTargetWasShown = nil
  dragTargetAlpha = nil
end

local function StopMoving()
  if not currentDragTarget then return end
  if currentDragTarget.StopMovingOrSizing then pcall(currentDragTarget.StopMovingOrSizing, currentDragTarget) end
  if not SaveElvUIPosition(currentDragTarget) then SaveNativePosition(currentDragTarget) end
  LinkBarToMover(currentBar, currentMover)
  SuppressDuplicateMovers(currentMover, currentMoverKey)
  RestoreDragTargetVisibility()
  currentDragTarget = nil
end

local function CreateHandle()
  if handle then return handle end
  handle = CreateFrame("Button", "RetreatUITotemBarDragHandle", UIParent)
  handle:SetSize(18, 36)
  handle:SetFrameStrata("DIALOG")
  handle:SetClampedToScreen(true)
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")

  handle.background = handle:CreateTexture(nil, "BACKGROUND")
  handle.background:SetAllPoints()
  handle.background:SetTexture("Interface\\Buttons\\WHITE8X8")
  handle.background:SetVertexColor(0.02, 0.02, 0.02, 0.55)

  handle.text = handle:CreateFontString(nil, "OVERLAY")
  RUI:ApplyFont(handle.text, 10, "OUTLINE")
  handle.text:SetPoint("CENTER")
  handle.text:SetText("::")
  handle:SetAlpha(0.20)

  handle:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:SetText("Move Totem Bar", 1, 1, 1)
      GameTooltip:AddLine("Drag this grip while out of combat.", 0.7, 0.7, 0.7, true)
      GameTooltip:Show()
    end
  end)
  handle:SetScript("OnLeave", function(self)
    self:SetAlpha(0.20)
    if GameTooltip then GameTooltip:Hide() end
  end)
  handle:SetScript("OnDragStart", function()
    if InCombatLockdown and InCombatLockdown() then
      RUI:Print("Leave combat before moving the Totem Bar.")
      return
    end
    local bar = currentBar or ResolveBar()
    local target = currentMover or bar
    if not target then return end

    currentBar = bar
    currentDragTarget = target
    if currentMover then LinkBarToMover(currentBar, currentMover) end

    if type(target.IsShown) == "function" then dragTargetWasShown = target:IsShown() end
    if type(target.GetAlpha) == "function" then dragTargetAlpha = target:GetAlpha() end
    if dragTargetWasShown == false and type(target.Show) == "function" then
      target:Show()
      if type(target.SetAlpha) == "function" then target:SetAlpha(0) end
    end

    if target.SetMovable then pcall(target.SetMovable, target, true) end
    if target.StartMoving then pcall(target.StartMoving, target) end
  end)
  handle:SetScript("OnDragStop", StopMoving)
  handle:Hide()
  return handle
end

local function Attach()
  if not IsWitchDoctor() then
    currentBar = nil
    currentMover = nil
    currentMoverKey = nil
    RestoreSuppressedMovers()
    if handle then handle:Hide() end
    return false
  end

  local bar = ResolveBar()
  if not bar then
    currentBar = nil
    currentMover = nil
    currentMoverKey = nil
    if handle then handle:Hide() end
    return false
  end

  currentBar = bar
  currentMover, currentMoverKey = ResolveMover(bar)
  ApplySavedPosition(currentMover, currentMoverKey, bar)
  if currentMover then LinkBarToMover(currentBar, currentMover) end
  SuppressDuplicateMovers(currentMover, currentMoverKey)

  -- Keep the grip attached to the visible bar, not to an invisible mover.
  -- Dragging still moves the ElvUI mover, but the grip and totem buttons now
  -- travel as one visual unit.
  local anchorFrame = currentBar
  local grip = CreateHandle()
  grip:ClearAllPoints()
  grip:SetPoint("RIGHT", anchorFrame, "LEFT", -3, 0)
  if bar.IsShown and bar:IsShown() then grip:Show() else grip:Hide() end
  return true
end

function RUI:InitializeTotemBarMover()
  Attach()
  if refreshFrame then return true end
  refreshFrame = CreateFrame("Frame")
  local elapsed = 0
  refreshFrame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.35 then return end
    elapsed = 0
    if not IsWitchDoctor() then
      RestoreSuppressedMovers()
      if handle then handle:Hide() end
      return
    end

    -- Never reapply the saved mover position while the user is actively
    -- dragging it. Doing so would snap the real Totem Bar back mid-drag.
    if currentDragTarget then return end

    -- Ascension and ElvUI may rebuild either Totem Bar frame. Re-resolving also
    -- guarantees the inactive duplicate mover stays absent from Toggle Anchors.
    Attach()
    if handle and currentBar then
      if currentBar.IsShown and currentBar:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
        handle:Show()
      else
        handle:Hide()
      end
    end
  end)
  return true
end

RUI._totemBarMoverLoaded = true
