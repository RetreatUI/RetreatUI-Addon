local RUI = RetreatUI
if not RUI then return end

local editor
local handles = {}
local definitionsByKey = {}
local selectedKey
local dragElapsed = 0

local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.60, 1.60, 0.05

local HUD_DEFINITIONS = {
  {key="core", label="MAIN ROTATION", width=430, height=44, kind="hud"},
  {key="utility", label="UTILITY", width=360, height=38, kind="hud"},
  {key="auraTrackers", label="PROCS / BUFFS", width=300, height=36, kind="hud"},
  {key="demonfire", label="CLASS RESOURCE", width=330, height=34, kind="hud"},
  {key="power", label="PRIMARY POWER", width=360, height=24, kind="hud"},
  {key="targetDebuffs", label="TARGET DEBUFFS", width=210, height=58, kind="hud"},
  {key="partyInterrupts", label="PARTY INTERRUPTS", width=190, height=110, kind="hud"},
}

local UNITFRAME_DEFINITIONS = {
  {key="ufPlayer", label="PLAYER FRAME", kind="unitframe", unit="player", mover="ElvUF_PlayerMover", frameNames={"ElvUF_Player"}},
  {key="ufTarget", label="TARGET FRAME", kind="unitframe", unit="target", mover="ElvUF_TargetMover", frameNames={"ElvUF_Target"}},
  {key="ufTargetTarget", label="TARGET OF TARGET", kind="unitframe", unit="targettarget", mover="ElvUF_TargetTargetMover", frameNames={"ElvUF_TargetTarget"}},
  {key="ufPet", label="PET FRAME", kind="unitframe", unit="pet", mover="ElvUF_PetMover", frameNames={"ElvUF_Pet"}},
  {key="ufFocus", label="FOCUS FRAME", kind="unitframe", unit="focus", mover="ElvUF_FocusMover", frameNames={"ElvUF_Focus"}},
  {key="ufParty", label="PARTY FRAMES", kind="unitframe", unit="party", mover="ElvUF_PartyMover", frameNames={"ElvUF_Party", "ElvUF_PartyGroup1"}},
  {key="ufRaid", label="RAID FRAMES", kind="unitframe", unit="raid", mover="ElvUF_RaidMover", frameNames={"ElvUF_Raid", "ElvUF_RaidGroup1"}},
  {key="ufPlayerCastbar", label="PLAYER CASTBAR", kind="unitframe", unit="player", sub="castbar", mover="ElvUF_PlayerCastbarMover", frameNames={"ElvUF_PlayerCastbar"}, owner="ElvUF_Player", child="Castbar"},
  {key="ufTargetCastbar", label="TARGET CASTBAR", kind="unitframe", unit="target", sub="castbar", mover="ElvUF_TargetCastbarMover", frameNames={"ElvUF_TargetCastbar"}, owner="ElvUF_Target", child="Castbar"},
}

for _, definition in ipairs(HUD_DEFINITIONS) do definitionsByKey[definition.key] = definition end
for _, definition in ipairs(UNITFRAME_DEFINITIONS) do definitionsByKey[definition.key] = definition end

local function Round(value, precision)
  local multiplier = 10 ^ (precision or 0)
  return math.floor((tonumber(value) or 0) * multiplier + 0.5) / multiplier
end

local function ClampScale(value)
  value = tonumber(value) or 1
  if value < MIN_SCALE then value = MIN_SCALE end
  if value > MAX_SCALE then value = MAX_SCALE end
  return Round(value, 2)
end

local function LayoutEntry(key)
  RUI.layout = RUI.layout or {}
  RUI.layout[key] = RUI.layout[key] or {}
  if RUI.layout[key].scale == nil then RUI.layout[key].scale = 1 end
  return RUI.layout[key]
end

local function UnitFrameStore()
  local db = RUI:EnsureDB()
  db.hudEditor = db.hudEditor or {}
  db.hudEditor.unitFrames = db.hudEditor.unitFrames or {}
  return db.hudEditor.unitFrames
end

local function UnitFrameEntry(key)
  local store = UnitFrameStore()
  store[key] = store[key] or {scale=1}
  if store[key].scale == nil then store[key].scale = 1 end
  return store[key]
end

local function ElvUIEngine()
  if RUI.IsUnsupportedElvUIInstalled and RUI:IsUnsupportedElvUIInstalled() then return nil end
  if not ElvUI or type(ElvUI) ~= "table" then return nil end
  local ok, engine = pcall(function() return unpack(ElvUI) end)
  if not ok or type(engine) ~= "table" then return nil end
  return engine
end

local function CurrentElvUIProfile(E)
  if E and E.data and E.data.GetCurrentProfile then
    local ok, value = pcall(E.data.GetCurrentProfile, E.data)
    if ok and type(value) == "string" and value ~= "" then return value end
  end
  return "RetreatUI"
end

local function PersistedElvUIProfile(E)
  if type(ElvDB) ~= "table" or type(ElvDB.profiles) ~= "table" then return nil end
  local profileName = CurrentElvUIProfile(E)
  return ElvDB.profiles[profileName] or ElvDB.profiles.RetreatUI
end

local function ResolveUnitFrame(definition)
  if not definition then return nil end
  for _, name in ipairs(definition.frameNames or {}) do
    local frame = _G[name]
    if frame and type(frame.GetCenter) == "function" then return frame end
  end
  if definition.owner and definition.child then
    local owner = _G[definition.owner]
    local frame = owner and owner[definition.child]
    if frame and type(frame.GetCenter) == "function" then return frame end
  end
  local mover = definition.mover and _G[definition.mover]
  if mover and type(mover.GetCenter) == "function" then return mover end
  return nil
end

local function LiveUnitConfig(E, definition)
  local units = E and E.db and E.db.unitframe and E.db.unitframe.units
  local config = units and units[definition.unit]
  if definition.sub and type(config) == "table" then config = config[definition.sub] end
  return type(config) == "table" and config or nil
end

local function SavedUnitConfig(profile, definition)
  local units = profile and profile.unitframe and profile.unitframe.units
  local config = units and units[definition.unit]
  if definition.sub and type(config) == "table" then config = config[definition.sub] end
  return type(config) == "table" and config or nil
end

local function BaselineUnitConfig(definition)
  local baseline = RUI.ElvUIProfile
  local units = baseline and baseline.unitframe and baseline.unitframe.units
  local config = units and units[definition.unit]
  if definition.sub and type(config) == "table" then config = config[definition.sub] end
  return type(config) == "table" and config or nil
end

local function EnsureUnitFrameBaseline(definition, E)
  local entry = UnitFrameEntry(definition.key)
  local live = LiveUnitConfig(E, definition)
  local baseline = BaselineUnitConfig(definition)
  local currentScale = ClampScale(entry.scale)

  if entry.baseWidth == nil then
    local width = baseline and tonumber(baseline.width) or live and tonumber(live.width)
    if width and not (baseline and tonumber(baseline.width)) and currentScale > 0 then width = width / currentScale end
    entry.baseWidth = width
  end
  if entry.baseHeight == nil then
    local height = baseline and tonumber(baseline.height) or live and tonumber(live.height)
    if height and not (baseline and tonumber(baseline.height)) and currentScale > 0 then height = height / currentScale end
    entry.baseHeight = height
  end
  if entry.baseMover == nil and definition.mover then
    local baselineMover = RUI.ElvUIProfile and RUI.ElvUIProfile.movers and RUI.ElvUIProfile.movers[definition.mover]
    local liveMover = E and E.db and E.db.movers and E.db.movers[definition.mover]
    entry.baseMover = baselineMover or liveMover
  end
  return entry
end

local function RefreshElvUI(E)
  if not E then return end
  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
  if E.UpdateAll then pcall(E.UpdateAll, E, true) end
  if E.UpdateMoverPositions then pcall(E.UpdateMoverPositions, E) end
end

local function GetPosition(key)
  local definition = definitionsByKey[key]
  if definition and definition.kind == "unitframe" then
    local frame = ResolveUnitFrame(definition)
    local centerX, centerY = frame and frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if centerX and centerY and parentX and parentY then return centerX - parentX, centerY - parentY end
    return nil, nil
  end

  local entry = LayoutEntry(key)
  if key == "partyInterrupts" and entry.autoAnchor ~= false and RUI.GetPartyInterruptDefaultPosition then
    return RUI:GetPartyInterruptDefaultPosition()
  end
  return tonumber(entry.x) or 0, tonumber(entry.y) or 0
end

function RUI:GetHUDScale(key)
  return ClampScale(LayoutEntry(key).scale)
end

function RUI:ApplyHUDFrameScale(frame, key)
  if not frame or type(frame.SetScale) ~= "function" then return false end
  frame:SetScale(self:GetHUDScale(key))
  return true
end

local function GetDefinitionScale(definition)
  if not definition then return 1 end
  if definition.kind == "unitframe" then return ClampScale(UnitFrameEntry(definition.key).scale) end
  return RUI:GetHUDScale(definition.key)
end

local function SetHUDPosition(key, x, y, save)
  local entry = LayoutEntry(key)
  if key == "partyInterrupts" then entry.autoAnchor = false end
  entry.x = math.floor((tonumber(x) or 0) + 0.5)
  entry.y = math.floor((tonumber(y) or 0) + 0.5)
  if save and RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
  if RUI.ApplyHUDLayout then RUI:ApplyHUDLayout(true) end
end

local function SetUnitFramePosition(definition, x, y)
  local E = ElvUIEngine()
  if not E or not E.db then return false end
  local profile = PersistedElvUIProfile(E)
  E.db.movers = E.db.movers or {}
  if profile then profile.movers = profile.movers or {} end

  local mover = string.format("CENTER,ElvUIParent,CENTER,%d,%d",
    math.floor((tonumber(x) or 0) + 0.5), math.floor((tonumber(y) or 0) + 0.5))
  E.db.movers[definition.mover] = mover
  if profile then profile.movers[definition.mover] = mover end

  local entry = EnsureUnitFrameBaseline(definition, E)
  entry.mover = mover
  RefreshElvUI(E)
  return true
end

local function RefreshEditorText()
  if not editor then return end
  local definition = selectedKey and definitionsByKey[selectedKey]
  if definition then
    local scale = GetDefinitionScale(definition)
    local kind = definition.kind == "unitframe" and "Unit frame" or "HUD"
    editor.selectedText:SetText(string.format("Selected: %s  |  %s scale: %d%%", definition.label, kind, math.floor(scale * 100 + 0.5)))
  else
    editor.selectedText:SetText("Select an anchor, then drag it or use the scale controls")
  end
end

local function ApplyHandlePosition(handle)
  if not handle then return false end
  local definition = handle.definition
  local x, y = GetPosition(handle.key)
  if x == nil or y == nil then
    handle:Hide()
    return false
  end

  handle:ClearAllPoints()
  handle:SetPoint("CENTER", UIParent, "CENTER", x, y)

  if definition.kind == "unitframe" then
    local frame = ResolveUnitFrame(definition)
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frameScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or parentScale
    local width = frame and frame.GetWidth and frame:GetWidth()
    local height = frame and frame.GetHeight and frame:GetHeight()
    if width and height and width > 1 and height > 1 then
      handle:SetSize(math.max(70, width * frameScale / parentScale), math.max(24, height * frameScale / parentScale))
    else
      handle:SetSize(definition.width or 160, definition.height or 36)
    end
  else
    handle:SetSize(definition.width, definition.height)
  end

  local scale = GetDefinitionScale(definition)
  handle.scaleText:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
  return true
end

local function SetSelected(key)
  selectedKey = key
  for _, handle in pairs(handles) do
    local active = handle.key == key
    if handle.SetBackdropBorderColor then
      if active then handle:SetBackdropBorderColor(1.00, 0.55, 0.12, 1)
      elseif handle.definition.kind == "unitframe" then handle:SetBackdropBorderColor(0.14, 0.72, 1.00, 1)
      else handle:SetBackdropBorderColor(0.35, 0.35, 0.42, 1) end
    end
  end
  RefreshEditorText()
end

local function SetUnitFrameScale(definition, value)
  local E = ElvUIEngine()
  if not E or not E.db then return false end
  local profile = PersistedElvUIProfile(E)
  local live = LiveUnitConfig(E, definition)
  if not live then return false end

  local entry = EnsureUnitFrameBaseline(definition, E)
  local scale = ClampScale(value)
  entry.scale = scale
  local width = tonumber(entry.baseWidth)
  local height = tonumber(entry.baseHeight)
  if width then live.width = math.max(1, math.floor(width * scale + 0.5)) end
  if height then live.height = math.max(1, math.floor(height * scale + 0.5)) end

  local saved = SavedUnitConfig(profile, definition)
  if saved then
    if width then saved.width = live.width end
    if height then saved.height = live.height end
  end

  RefreshElvUI(E)
  return width ~= nil or height ~= nil
end

local function SetScale(key, value, save)
  if not key then return false end
  local definition = definitionsByKey[key]
  if not definition then return false end

  if definition.kind == "unitframe" then
    if not SetUnitFrameScale(definition, value) then
      RUI:Print("That ElvUI frame is not available for scaling right now.")
      return false
    end
  else
    local entry = LayoutEntry(key)
    entry.scale = ClampScale(value)
    if RUI.ApplyHUDLayout then RUI:ApplyHUDLayout(true) end
    if save and RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
  end

  if handles[key] then
    RUI:After(0.05, function()
      if handles[key] and editor and editor:IsShown() then
        ApplyHandlePosition(handles[key])
        handles[key]:Show()
      end
    end)
  end
  RefreshEditorText()
  return true
end

local function AdjustScale(key, delta, save)
  local definition = key and definitionsByKey[key]
  if not definition then return false end
  return SetScale(key, GetDefinitionScale(definition) + (tonumber(delta) or 0), save)
end

local function ScaleAllHUD(delta)
  for _, definition in ipairs(HUD_DEFINITIONS) do
    local key = definition.key
    LayoutEntry(key).scale = ClampScale(RUI:GetHUDScale(key) + delta)
  end
  if RUI.ApplyHUDLayout then RUI:ApplyHUDLayout(true) end
  for _, definition in ipairs(HUD_DEFINITIONS) do
    local handle = handles[definition.key]
    if handle then ApplyHandlePosition(handle) end
  end
  if RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
  RefreshEditorText()
end

local function ResetUnitFrame(definition)
  local E = ElvUIEngine()
  if not E or not E.db then return false end
  local profile = PersistedElvUIProfile(E)
  local entry = EnsureUnitFrameBaseline(definition, E)
  local baseline = BaselineUnitConfig(definition)
  local live = LiveUnitConfig(E, definition)
  local saved = SavedUnitConfig(profile, definition)

  local width = baseline and tonumber(baseline.width) or tonumber(entry.baseWidth)
  local height = baseline and tonumber(baseline.height) or tonumber(entry.baseHeight)
  if live then
    if width then live.width = width end
    if height then live.height = height end
  end
  if saved then
    if width then saved.width = width end
    if height then saved.height = height end
  end

  local mover = RUI.ElvUIProfile and RUI.ElvUIProfile.movers and RUI.ElvUIProfile.movers[definition.mover]
  mover = mover or entry.baseMover
  if mover then
    E.db.movers = E.db.movers or {}
    E.db.movers[definition.mover] = mover
    if profile then
      profile.movers = profile.movers or {}
      profile.movers[definition.mover] = mover
    end
  end

  entry.scale = 1
  entry.mover = mover
  RefreshElvUI(E)
  return true
end

local function UpdateDraggedHandle(handle)
  if not handle or not handle:IsDragging() then return end
  if handle.definition.kind == "unitframe" then return end
  local centerX, centerY = handle:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if not centerX or not parentX then return end
  SetHUDPosition(handle.key, centerX - parentX, centerY - parentY, false)
end

local function CreateHandle(definition)
  local handle = CreateFrame("Button", "RetreatUIHUDEditor" .. definition.key, UIParent)
  handle.key = definition.key
  handle.definition = definition
  handle:SetSize(definition.width or 160, definition.height or 36)
  handle:SetFrameStrata("DIALOG")
  handle:SetFrameLevel(50)
  handle:SetMovable(true)
  handle:EnableMouse(true)
  handle:EnableMouseWheel(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetClampedToScreen(true)
  handle:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8X8",
    edgeFile="Interface\\Buttons\\WHITE8X8",
    tile=true, tileSize=8, edgeSize=1,
    insets={left=1,right=1,top=1,bottom=1},
  })
  if definition.kind == "unitframe" then
    handle:SetBackdropColor(0.02, 0.10, 0.16, 0.64)
    handle:SetBackdropBorderColor(0.14, 0.72, 1.00, 1)
  else
    handle:SetBackdropColor(0.04, 0.04, 0.06, 0.72)
    handle:SetBackdropBorderColor(0.35, 0.35, 0.42, 1)
  end

  handle.text = handle:CreateFontString(nil, "OVERLAY")
  handle.text:SetPoint("CENTER", 0, 2)
  RUI:ApplyFont(handle.text, definition.kind == "unitframe" and 9 or 11, "OUTLINE")
  handle.text:SetText(definition.label .. "\nDrag to move")
  handle.text:SetTextColor(1, 1, 1, 1)

  handle.scaleText = handle:CreateFontString(nil, "OVERLAY")
  handle.scaleText:SetPoint("TOPRIGHT", -4, -3)
  RUI:ApplyFont(handle.scaleText, 8, "OUTLINE")
  handle.scaleText:SetTextColor(1.00, 0.70, 0.25, 1)

  handle:SetScript("OnMouseDown", function(self) SetSelected(self.key) end)
  handle:SetScript("OnMouseWheel", function(self, delta)
    if InCombatLockdown and InCombatLockdown() then return end
    SetSelected(self.key)
    AdjustScale(self.key, delta > 0 and SCALE_STEP or -SCALE_STEP, true)
  end)
  handle:SetScript("OnDragStart", function(self)
    if InCombatLockdown and InCombatLockdown() then
      RUI:Print("HUD editing is unavailable during combat.")
      return
    end
    self._dragging = true
    self:StartMoving()
    SetSelected(self.key)
  end)
  handle:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self._dragging = false
    local centerX, centerY = self:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not centerX or not parentX then return end
    local x, y = centerX - parentX, centerY - parentY
    if self.definition.kind == "unitframe" then
      SetUnitFramePosition(self.definition, x, y)
    else
      SetHUDPosition(self.key, x, y, true)
    end
    RUI:After(0.05, function()
      if editor and editor:IsShown() and ApplyHandlePosition(self) then self:Show() end
    end)
  end)
  handle.IsDragging = function(self) return self._dragging == true end
  handle:Hide()
  handles[definition.key] = handle
  return handle
end

local function Button(parent, text, width, callback)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, 24)
  button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  button:SetBackdropColor(0.10, 0.10, 0.13, 0.96)
  button:SetBackdropBorderColor(0.32, 0.32, 0.38, 1)
  button.text = button:CreateFontString(nil, "OVERLAY")
  button.text:SetPoint("CENTER")
  RUI:ApplyFont(button.text, 10, "OUTLINE")
  button.text:SetText(text)
  button:SetScript("OnClick", callback)
  return button
end

local function BuildEditor()
  if editor then return editor end
  editor = CreateFrame("Frame", "RetreatUIHUDEditorWindow", UIParent)
  editor:SetSize(610, 205)
  editor:SetPoint("TOP", UIParent, "TOP", 0, -55)
  editor:SetFrameStrata("DIALOG")
  editor:SetFrameLevel(60)
  editor:SetMovable(true)
  editor:EnableMouse(true)
  editor:RegisterForDrag("LeftButton")
  editor:SetClampedToScreen(true)
  editor:SetBackdrop({
    bgFile="Interface\\Buttons\\WHITE8X8",
    edgeFile="Interface\\Buttons\\WHITE8X8",
    tile=true, tileSize=8, edgeSize=1,
    insets={left=1,right=1,top=1,bottom=1},
  })
  editor:SetBackdropColor(0.018, 0.018, 0.024, 0.98)
  editor:SetBackdropBorderColor(1.00, 0.35, 0.08, 1)
  editor:SetScript("OnDragStart", function(self)
    if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
  end)
  editor:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  editor.title = editor:CreateFontString(nil, "OVERLAY")
  editor.title:SetPoint("TOPLEFT", 14, -12)
  RUI:ApplyFont(editor.title, 14, "OUTLINE")
  editor.title:SetText("RetreatUI HUD & Unit Frame Editor")

  editor.status = editor:CreateFontString(nil, "OVERLAY")
  editor.status:SetPoint("TOPLEFT", editor.title, "BOTTOMLEFT", 0, -6)
  RUI:ApplyFont(editor.status, 9, "OUTLINE")
  editor.status:SetTextColor(0.78, 0.78, 0.84, 1)

  editor.selectedText = editor:CreateFontString(nil, "OVERLAY")
  editor.selectedText:SetPoint("TOPLEFT", editor.status, "BOTTOMLEFT", 0, -6)
  RUI:ApplyFont(editor.selectedText, 9, "OUTLINE")

  editor.helpText = editor:CreateFontString(nil, "OVERLAY")
  editor.helpText:SetPoint("TOPLEFT", editor.selectedText, "BOTTOMLEFT", 0, -5)
  RUI:ApplyFont(editor.helpText, 8, "OUTLINE")
  editor.helpText:SetTextColor(0.62, 0.62, 0.68, 1)
  editor.helpText:SetText("Grey anchors are RetreatUI HUD sections. Blue anchors are managed ElvUI unit frames. Drag or use the mouse wheel to scale.")

  editor.scaleDown = Button(editor, "-5%", 58, function() AdjustScale(selectedKey, -SCALE_STEP, true) end)
  editor.scaleDown:SetPoint("TOPLEFT", editor.helpText, "BOTTOMLEFT", 0, -10)

  editor.scaleReset = Button(editor, "100%", 66, function() SetScale(selectedKey, 1, true) end)
  editor.scaleReset:SetPoint("LEFT", editor.scaleDown, "RIGHT", 6, 0)

  editor.scaleUp = Button(editor, "+5%", 58, function() AdjustScale(selectedKey, SCALE_STEP, true) end)
  editor.scaleUp:SetPoint("LEFT", editor.scaleReset, "RIGHT", 6, 0)

  editor.scaleAllDown = Button(editor, "HUD -5%", 78, function() ScaleAllHUD(-SCALE_STEP) end)
  editor.scaleAllDown:SetPoint("LEFT", editor.scaleUp, "RIGHT", 18, 0)

  editor.scaleAllUp = Button(editor, "HUD +5%", 78, function() ScaleAllHUD(SCALE_STEP) end)
  editor.scaleAllUp:SetPoint("LEFT", editor.scaleAllDown, "RIGHT", 6, 0)

  editor.resetSelected = Button(editor, "Reset Selected", 115, function()
    if not selectedKey then return end
    local definition = definitionsByKey[selectedKey]
    if definition and definition.kind == "unitframe" then
      ResetUnitFrame(definition)
    elseif RUI.ResetCurrentHUDLayout then
      RUI:ResetCurrentHUDLayout(selectedKey)
    end
    RUI:After(0.05, function()
      local handle = handles[selectedKey]
      if handle and editor and editor:IsShown() and ApplyHandlePosition(handle) then handle:Show() end
      RefreshEditorText()
    end)
  end)
  editor.resetSelected:SetPoint("BOTTOMLEFT", 14, 12)

  editor.resetClass = Button(editor, "Reset HUD", 92, function()
    if RUI.ResetCurrentHUDLayout then RUI:ResetCurrentHUDLayout(nil) end
    for _, definition in ipairs(HUD_DEFINITIONS) do
      local handle = handles[definition.key]
      if handle then ApplyHandlePosition(handle) end
    end
    RefreshEditorText()
  end)
  editor.resetClass:SetPoint("LEFT", editor.resetSelected, "RIGHT", 6, 0)

  editor.save = Button(editor, "Save", 74, function()
    if RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
    RUI:Print("HUD layout saved. ElvUI unit-frame changes are stored in the active profile.")
  end)
  editor.save:SetPoint("LEFT", editor.resetClass, "RIGHT", 6, 0)

  editor.close = Button(editor, "Close", 74, function() RUI:CloseHUDEditor() end)
  editor.close:SetPoint("LEFT", editor.save, "RIGHT", 6, 0)

  editor:SetScript("OnUpdate", function(_, elapsed)
    dragElapsed = dragElapsed + elapsed
    if dragElapsed < 0.05 then return end
    dragElapsed = 0
    for _, handle in pairs(handles) do
      if handle:IsDragging() then UpdateDraggedHandle(handle) end
    end
  end)

  for _, definition in ipairs(HUD_DEFINITIONS) do CreateHandle(definition) end
  for _, definition in ipairs(UNITFRAME_DEFINITIONS) do CreateHandle(definition) end
  editor:Hide()
  return editor
end

function RUI:ApplyPrimaryPowerLayout()
  local frame = _G.RetreatUIPrimaryPowerBar
  local layout = self.layout and self.layout.power
  if not frame or not layout then return false end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(layout.x) or 0, tonumber(layout.y) or -152)
  if layout.width and layout.height then frame:SetSize(layout.width, layout.height) end
  self:ApplyHUDFrameScale(frame, "power")
  return true
end

function RUI:ApplyHUDLayout(force)
  self:ApplyPrimaryPowerLayout()
  if type(self.ApplyPartyInterruptLayout) == "function" then self:ApplyPartyInterruptLayout() end
  local module = self.activeModule
  if module and type(module.refreshLayout) == "function" then
    pcall(module.refreshLayout, module, force == true)
    return true
  end

  local root = module and module.frameName and _G[module.frameName]
  if not root then return false end
  local core = self.layout.core or {x=0,y=-183}
  local utility = self.layout.utility or {x=0,y=-224}
  if root.coreRow then
    root.coreRow:ClearAllPoints()
    root.coreRow:SetPoint("CENTER", UIParent, "CENTER", tonumber(core.x) or 0, tonumber(core.y) or -183)
    self:ApplyHUDFrameScale(root.coreRow, "core")
  end
  if root.utilityRow then
    root.utilityRow:ClearAllPoints()
    root.utilityRow:SetPoint("CENTER", UIParent, "CENTER", tonumber(utility.x) or 0, tonumber(utility.y) or -224)
    self:ApplyHUDFrameScale(root.utilityRow, "utility")
  end
  return true
end

function RUI:OpenHUDEditor()
  if InCombatLockdown and InCombatLockdown() then
    self:Print("HUD editing is unavailable during combat.")
    return false
  end
  if type(self.IsSupportedCharacter) == "function" and not self:IsSupportedCharacter() then
    self:Print("No supported RetreatUI class HUD is active.")
    return false
  end
  if self.RefreshBuildProfile then self:RefreshBuildProfile("HUD_EDITOR", false) end
  BuildEditor()
  if self.SetPartyInterruptEditorPreview then self:SetPartyInterruptEditorPreview(true) end

  local className, buildKey, count = self:GetBuildProfileStatus()
  local buildState = self.GetCurrentBuildState and self:GetCurrentBuildState(false) or nil
  local learned = buildState and buildState.learnedCount or 0
  local slot = buildState and buildState.activeSlot or 1
  local unitFrameState = ElvUIEngine() and "ElvUI frames enabled" or "ElvUI frames unavailable"
  editor.status:SetText(tostring(className) .. "  |  Build " .. tostring(buildKey) .. "  |  Slot " .. tostring(slot)
    .. "  |  " .. tostring(learned) .. " learned HUD records  |  " .. tostring(count) .. " profile(s)  |  " .. unitFrameState)

  for _, handle in pairs(handles) do
    handle._dragging = false
    if ApplyHandlePosition(handle) then handle:Show() else handle:Hide() end
  end
  editor:Show()
  SetSelected(selectedKey)
  return true
end

function RUI:CloseHUDEditor()
  if self.SaveCurrentHUDLayout then self:SaveCurrentHUDLayout() end
  if self.SetPartyInterruptEditorPreview then self:SetPartyInterruptEditorPreview(false) end
  if editor then editor:Hide() end
  for _, handle in pairs(handles) do
    handle._dragging = false
    handle:StopMovingOrSizing()
    handle:Hide()
  end
  return true
end

function RUI:ToggleHUDEditor()
  BuildEditor()
  if editor:IsShown() then return self:CloseHUDEditor() end
  return self:OpenHUDEditor()
end

RUI._hudEditorLoaded = true
