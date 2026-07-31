local RUI = RetreatUI
if not RUI then return end

local editor
local handles = {}
local selectedKey
local dragElapsed = 0

local MIN_SCALE, MAX_SCALE, SCALE_STEP = 0.60, 1.60, 0.05

local DEFINITIONS = {
  {key="core", label="MAIN ROTATION", width=430, height=44},
  {key="utility", label="UTILITY", width=360, height=38},
  {key="auraTrackers", label="PROCS / BUFFS", width=300, height=36},
  {key="demonfire", label="CLASS RESOURCE", width=330, height=34},
  {key="power", label="PRIMARY POWER", width=360, height=24},
  {key="targetDebuffs", label="TARGET DEBUFFS", width=210, height=58},
}

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

local function GetPosition(key)
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

local function SetPosition(key, x, y, save)
  local entry = LayoutEntry(key)
  if key == "partyInterrupts" then entry.autoAnchor = false end
  entry.x = math.floor((tonumber(x) or 0) + 0.5)
  entry.y = math.floor((tonumber(y) or 0) + 0.5)
  if save and RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
  if RUI.ApplyHUDLayout then RUI:ApplyHUDLayout(true) end
end

local function RefreshEditorText()
  if not editor then return end
  if selectedKey then
    local scale = RUI:GetHUDScale(selectedKey)
    editor.selectedText:SetText(string.format("Selected: %s  |  Scale: %d%%", tostring(selectedKey), math.floor(scale * 100 + 0.5)))
  else
    editor.selectedText:SetText("Select an anchor, then use the scale controls or mouse wheel")
  end
end

local function ApplyHandlePosition(handle)
  local x, y = GetPosition(handle.key)
  handle:ClearAllPoints()
  handle:SetPoint("CENTER", UIParent, "CENTER", x, y)
  local scale = RUI:GetHUDScale(handle.key)
  handle.scaleText:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
end

local function SetSelected(key)
  selectedKey = key
  for _, handle in pairs(handles) do
    local active = handle.key == key
    if handle.SetBackdropBorderColor then
      if active then handle:SetBackdropBorderColor(1.00, 0.55, 0.12, 1)
      else handle:SetBackdropBorderColor(0.35, 0.35, 0.42, 1) end
    end
  end
  RefreshEditorText()
end

local function SetScale(key, value, save)
  if not key then return false end
  local entry = LayoutEntry(key)
  entry.scale = ClampScale(value)
  if RUI.ApplyHUDLayout then RUI:ApplyHUDLayout(true) end
  if handles[key] then ApplyHandlePosition(handles[key]) end
  RefreshEditorText()
  if save and RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
  return true
end

local function AdjustScale(key, delta, save)
  return SetScale(key, RUI:GetHUDScale(key) + (tonumber(delta) or 0), save)
end

local function ScaleAll(delta)
  for _, definition in ipairs(DEFINITIONS) do
    local key = definition.key
    LayoutEntry(key).scale = ClampScale(RUI:GetHUDScale(key) + delta)
  end
  if RUI.ApplyHUDLayout then RUI:ApplyHUDLayout(true) end
  for _, handle in pairs(handles) do ApplyHandlePosition(handle) end
  if RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
  RefreshEditorText()
end

local function UpdateDraggedHandle(handle)
  if not handle or not handle:IsDragging() then return end
  local centerX, centerY = handle:GetCenter()
  local parentX, parentY = UIParent:GetCenter()
  if not centerX or not parentX then return end
  SetPosition(handle.key, centerX - parentX, centerY - parentY, false)
end

local function CreateHandle(definition)
  local handle = CreateFrame("Button", "RetreatUIHUDEditor" .. definition.key, UIParent)
  handle.key = definition.key
  handle:SetSize(definition.width, definition.height)
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
  handle:SetBackdropColor(0.04, 0.04, 0.06, 0.72)
  handle:SetBackdropBorderColor(0.35, 0.35, 0.42, 1)

  handle.text = handle:CreateFontString(nil, "OVERLAY")
  handle.text:SetPoint("CENTER", 0, 3)
  RUI:ApplyFont(handle.text, 11, "OUTLINE")
  handle.text:SetText(definition.label .. "\nDrag to move")
  handle.text:SetTextColor(1, 1, 1, 1)

  handle.scaleText = handle:CreateFontString(nil, "OVERLAY")
  handle.scaleText:SetPoint("TOPRIGHT", -5, -4)
  RUI:ApplyFont(handle.scaleText, 9, "OUTLINE")
  handle.scaleText:SetTextColor(1.00, 0.70, 0.25, 1)

  handle:SetScript("OnMouseDown", function(self)
    SetSelected(self.key)
  end)
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
    if centerX and parentX then SetPosition(self.key, centerX - parentX, centerY - parentY, true) end
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
  editor:SetSize(540, 184)
  editor:SetPoint("TOP", UIParent, "TOP", 0, -65)
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
  editor.title:SetText("RetreatUI HUD Editor")

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
  editor.helpText:SetText("Drag anchors to move. Mouse wheel or the buttons below scales the selected HUD section.")

  editor.scaleDown = Button(editor, "-5%", 58, function() AdjustScale(selectedKey, -SCALE_STEP, true) end)
  editor.scaleDown:SetPoint("TOPLEFT", editor.helpText, "BOTTOMLEFT", 0, -10)

  editor.scaleReset = Button(editor, "100%", 66, function() SetScale(selectedKey, 1, true) end)
  editor.scaleReset:SetPoint("LEFT", editor.scaleDown, "RIGHT", 6, 0)

  editor.scaleUp = Button(editor, "+5%", 58, function() AdjustScale(selectedKey, SCALE_STEP, true) end)
  editor.scaleUp:SetPoint("LEFT", editor.scaleReset, "RIGHT", 6, 0)

  editor.scaleAllDown = Button(editor, "All -5%", 78, function() ScaleAll(-SCALE_STEP) end)
  editor.scaleAllDown:SetPoint("LEFT", editor.scaleUp, "RIGHT", 18, 0)

  editor.scaleAllUp = Button(editor, "All +5%", 78, function() ScaleAll(SCALE_STEP) end)
  editor.scaleAllUp:SetPoint("LEFT", editor.scaleAllDown, "RIGHT", 6, 0)

  editor.resetSelected = Button(editor, "Reset Selected", 115, function()
    if not selectedKey then return end
    if RUI.ResetCurrentHUDLayout then RUI:ResetCurrentHUDLayout(selectedKey) end
    ApplyHandlePosition(handles[selectedKey])
    RefreshEditorText()
  end)
  editor.resetSelected:SetPoint("BOTTOMLEFT", 14, 12)

  editor.resetClass = Button(editor, "Reset Build", 100, function()
    if RUI.ResetCurrentHUDLayout then RUI:ResetCurrentHUDLayout(nil) end
    for _, handle in pairs(handles) do ApplyHandlePosition(handle) end
    RefreshEditorText()
  end)
  editor.resetClass:SetPoint("LEFT", editor.resetSelected, "RIGHT", 6, 0)

  editor.save = Button(editor, "Save", 74, function()
    if RUI.SaveCurrentHUDLayout then RUI:SaveCurrentHUDLayout() end
    RUI:Print("HUD layout and scale saved for the current build.")
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

  for _, definition in ipairs(DEFINITIONS) do CreateHandle(definition) end
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
  local className, buildKey, count = self:GetBuildProfileStatus()
  local buildState = self.GetCurrentBuildState and self:GetCurrentBuildState(false) or nil
  local learned = buildState and buildState.learnedCount or 0
  local slot = buildState and buildState.activeSlot or 1
  editor.status:SetText(tostring(className) .. "  |  Build " .. tostring(buildKey) .. "  |  Slot " .. tostring(slot) .. "  |  " .. tostring(learned) .. " learned HUD records  |  " .. tostring(count) .. " profile(s)")
  for _, handle in pairs(handles) do
    ApplyHandlePosition(handle)
    handle:Show()
  end
  editor:Show()
  SetSelected(selectedKey)
  return true
end

function RUI:CloseHUDEditor()
  if self.SaveCurrentHUDLayout then self:SaveCurrentHUDLayout() end
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
