local RUI = RetreatUI
if not RUI then return end

local editor
local handles = {}
local selectedKey
local GROWTH_ORDER = {"RIGHT", "LEFT", "UP", "DOWN"}
local GROWTH_LABEL = {RIGHT="Right", LEFT="Left", UP="Up", DOWN="Down"}

local function Backdrop(frame, alpha)
  if not frame or type(frame.SetBackdrop) ~= "function" then return end
  frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  frame:SetBackdropColor(0.02, 0.02, 0.025, alpha or 0.88)
  frame:SetBackdropBorderColor(0.75, 0.55, 0.05, 1)
end

local function NextGrowth(current)
  local index = 1
  for i, value in ipairs(GROWTH_ORDER) do if value == current then index = i break end end
  index = index + 1
  if index > #GROWTH_ORDER then index = 1 end
  return GROWTH_ORDER[index]
end

local function GroupDefinition(key)
  for _, definition in ipairs(RUI.trackerGroupDefinitions or {}) do
    if definition.key == key then return definition end
  end
  return nil
end

local function GroupTrackers(className, key)
  local grouped = RUI.GetTrackersByGroup and RUI:GetTrackersByGroup(className) or {}
  return grouped[key] or {}
end

local function PositionHandle(handle, className)
  if not handle then return end
  local layout = RUI:GetTrackerGroupLayout(className, handle.key)
  local trackers = GroupTrackers(className, handle.key)
  if not layout then return end

  handle:ClearAllPoints()
  handle:SetPoint("CENTER", UIParent, "CENTER", layout.x or 0, layout.y or 0)

  local count = #trackers
  local spacing = layout.spacing or 4
  local scale = layout.scale or 1
  local maxIcon, total = 34, 0
  for _, tracker in ipairs(trackers) do
    local size = tracker.settings and tonumber(tracker.settings.iconSize) or 36
    if size > maxIcon then maxIcon = size end
    total = total + size
  end
  if count > 1 then total = total + ((count - 1) * spacing) end
  if total <= 0 then total = 150 end

  if layout.growth == "UP" or layout.growth == "DOWN" then
    handle:SetWidth(math.max(150, (maxIcon * scale) + 20))
    handle:SetHeight(math.max(42, (total * scale) + 28))
  else
    handle:SetWidth(math.max(150, (total * scale) + 20))
    handle:SetHeight(math.max(42, (maxIcon * scale) + 28))
  end

  handle.label:SetText((handle.definition.label or handle.key) .. "  •  " .. tostring(count))
  handle.detail:SetText(string.format("%d%%  •  spacing %d  •  %s", math.floor(scale * 100 + 0.5), spacing, GROWTH_LABEL[layout.growth] or layout.growth))

  for index, texture in ipairs(handle.icons) do
    local tracker = trackers[index]
    if tracker then
      texture:Show()
      local spellID = tonumber(tracker.spellID)
      local icon = spellID and GetSpellTexture and GetSpellTexture(spellID)
      texture:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    else
      texture:Hide()
    end
  end
end

local function RefreshAll()
  if not editor then return end
  local className = RUI.GetDetectedClass and RUI:GetDetectedClass() or "Unknown"
  editor.className = className
  editor.classText:SetText("Class: |cffffffff" .. tostring(className) .. "|r")
  for _, handle in pairs(handles) do PositionHandle(handle, className) end

  local definition = selectedKey and GroupDefinition(selectedKey)
  if definition then
    local layout = RUI:GetTrackerGroupLayout(className, selectedKey)
    editor.selected:SetText("Selected: |cffffffff" .. tostring(definition.label) .. "|r")
    editor.scaleText:SetText(tostring(math.floor((layout.scale or 1) * 100 + 0.5)) .. "%")
    editor.spacingText:SetText(tostring(layout.spacing or 4) .. " px")
    editor.growth:SetText("Growth: " .. (GROWTH_LABEL[layout.growth] or layout.growth))
    editor.scaleMinus:Enable(); editor.scalePlus:Enable(); editor.spacingMinus:Enable(); editor.spacingPlus:Enable(); editor.growth:Enable(); editor.reset:Enable()
  else
    editor.selected:SetText("Click a group to edit it, or drag it directly.")
    editor.scaleText:SetText("—")
    editor.spacingText:SetText("—")
    editor.growth:SetText("Growth")
    editor.scaleMinus:Disable(); editor.scalePlus:Disable(); editor.spacingMinus:Disable(); editor.spacingPlus:Disable(); editor.growth:Disable(); editor.reset:Disable()
  end
end

local function SaveHandlePosition(handle)
  if not handle or not editor then return end
  local x, y = handle:GetCenter()
  local px, py = UIParent:GetCenter()
  if not x or not y or not px or not py then return end
  RUI:SetTrackerGroupLayout(editor.className, handle.key, {x=x-px, y=y-py})
  PositionHandle(handle, editor.className)
end

local function SelectHandle(handle)
  selectedKey = handle and handle.key or nil
  for key, current in pairs(handles) do
    if current.SetBackdropBorderColor then
      if key == selectedKey then current:SetBackdropBorderColor(1, 0.72, 0.05, 1)
      else current:SetBackdropBorderColor(0.35, 0.35, 0.38, 1) end
    end
  end
  RefreshAll()
end

local function CreateHandle(parent, definition)
  local handle = CreateFrame("Button", nil, parent)
  handle.key = definition.key
  handle.definition = definition
  handle:SetWidth(180); handle:SetHeight(48)
  handle:SetFrameStrata("FULLSCREEN_DIALOG")
  handle:EnableMouse(true)
  handle:SetMovable(true)
  handle:RegisterForDrag("LeftButton")
  Backdrop(handle, 0.78)

  handle.label = handle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  handle.label:SetPoint("TOP", handle, "TOP", 0, -5)
  handle.detail = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  handle.detail:SetPoint("BOTTOM", handle, "BOTTOM", 0, 5)

  handle.icons = {}
  for index=1,8 do
    local icon = handle:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(18); icon:SetHeight(18)
    icon:SetPoint("TOPLEFT", handle, "TOPLEFT", 4 + ((index-1) * 20), -4)
    icon:SetAlpha(0.30)
    icon:Hide()
    handle.icons[index] = icon
  end

  handle:SetScript("OnClick", function(self) SelectHandle(self) end)
  handle:SetScript("OnDragStart", function(self)
    SelectHandle(self)
    self:StartMoving()
  end)
  handle:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveHandlePosition(self)
    RefreshAll()
  end)
  return handle
end

local function CreateEditor(self)
  if self.trackerGroupLayoutEditor then return self.trackerGroupLayoutEditor end
  if type(CreateFrame) ~= "function" or not UIParent then return nil end

  local frame = CreateFrame("Frame", "RetreatUITrackerGroupLayoutEditor", UIParent)
  frame:SetAllPoints(UIParent)
  frame:SetFrameStrata("FULLSCREEN")
  frame:EnableMouse(false)

  local shade = frame:CreateTexture(nil, "BACKGROUND")
  shade:SetAllPoints(frame)
  shade:SetTexture("Interface\\Buttons\\WHITE8X8")
  shade:SetVertexColor(0,0,0,0.18)

  local panel = CreateFrame("Frame", nil, frame)
  panel:SetWidth(760); panel:SetHeight(92)
  panel:SetPoint("TOP", UIParent, "TOP", 0, -18)
  panel:SetFrameStrata("FULLSCREEN_DIALOG")
  panel:EnableMouse(true)
  Backdrop(panel, 0.96)
  frame.panel = panel

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 14, -12)
  title:SetText("RetreatUI  •  Tracker HUD Layout")
  frame.classText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.classText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

  frame.selected = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.selected:SetPoint("BOTTOMLEFT", 14, 12)
  frame.selected:SetWidth(250); frame.selected:SetJustifyH("LEFT")

  local function Button(text, width, x)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetWidth(width); button:SetHeight(24); button:SetPoint("BOTTOMLEFT", x, 10); button:SetText(text)
    return button
  end

  frame.scaleMinus = Button("Scale -", 64, 270)
  frame.scaleText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.scaleText:SetPoint("LEFT", frame.scaleMinus, "RIGHT", 6, 0); frame.scaleText:SetWidth(42)
  frame.scalePlus = Button("Scale +", 64, 380)
  frame.spacingMinus = Button("Space -", 68, 450)
  frame.spacingText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.spacingText:SetPoint("LEFT", frame.spacingMinus, "RIGHT", 5, 0); frame.spacingText:SetWidth(42)
  frame.spacingPlus = Button("Space +", 68, 565)
  frame.growth = Button("Growth", 104, 638)

  frame.reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  frame.reset:SetWidth(80); frame.reset:SetHeight(24); frame.reset:SetPoint("TOPRIGHT", -94, -10); frame.reset:SetText("Reset")
  frame.done = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  frame.done:SetWidth(80); frame.done:SetHeight(24); frame.done:SetPoint("TOPRIGHT", -10, -10); frame.done:SetText("Done")

  local function Change(values)
    if not selectedKey then return end
    RUI:SetTrackerGroupLayout(frame.className, selectedKey, values)
    RefreshAll()
  end
  frame.scaleMinus:SetScript("OnClick", function() local e=RUI:GetTrackerGroupLayout(frame.className, selectedKey); Change({scale=(e.scale or 1)-0.05}) end)
  frame.scalePlus:SetScript("OnClick", function() local e=RUI:GetTrackerGroupLayout(frame.className, selectedKey); Change({scale=(e.scale or 1)+0.05}) end)
  frame.spacingMinus:SetScript("OnClick", function() local e=RUI:GetTrackerGroupLayout(frame.className, selectedKey); Change({spacing=(e.spacing or 4)-1}) end)
  frame.spacingPlus:SetScript("OnClick", function() local e=RUI:GetTrackerGroupLayout(frame.className, selectedKey); Change({spacing=(e.spacing or 4)+1}) end)
  frame.growth:SetScript("OnClick", function() local e=RUI:GetTrackerGroupLayout(frame.className, selectedKey); Change({growth=NextGrowth(e.growth)}) end)
  frame.reset:SetScript("OnClick", function() if selectedKey then RUI:ResetTrackerGroupLayout(frame.className, selectedKey); RefreshAll() end end)
  frame.done:SetScript("OnClick", function() frame:Hide() end)

  for _, definition in ipairs(self.trackerGroupDefinitions or {}) do
    handles[definition.key] = CreateHandle(frame, definition)
  end

  frame:SetScript("OnShow", function() selectedKey=nil; RefreshAll() end)
  frame:Hide()
  self.trackerGroupLayoutEditor = frame
  editor = frame
  return frame
end

function RUI:OpenTrackerGroupLayoutEditor()
  local frame = CreateEditor(self)
  if not frame then return false end
  frame:Show()
  RefreshAll()
  return true
end

function RUI:ToggleTrackerGroupLayoutEditor()
  local frame = CreateEditor(self)
  if not frame then return false end
  if frame:IsShown() then frame:Hide(); return false end
  return self:OpenTrackerGroupLayoutEditor()
end
