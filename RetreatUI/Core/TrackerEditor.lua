local RUI = RetreatUI
if not RUI then return end

local TYPE_OPTIONS = {
  {"cooldown", "Cooldown"},
  {"buff", "Buff"},
  {"proc", "Proc"},
  {"debuff", "Debuff"},
  {"stacks", "Stacks"},
  {"charges", "Charges"},
  {"resource", "Resource"},
  {"summon", "Summon / Pet"},
}
local UNITS = {"player", "target", "focus", "pet"}
local UNIT_LABELS = {player="Player", target="Target", focus="Focus", pet="Pet"}
local DISPLAYS = {"icon", "bar"}
local DISPLAY_LABELS = {icon="Icon", bar="Bar"}
local GLOWS = {"off", "ready", "active"}
local GLOW_LABELS = {off="Off", ready="When ready", active="While active"}

local function Backdrop(frame)
  if not frame or type(frame.SetBackdrop) ~= "function" then return end
  frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  frame:SetBackdropColor(0.025,0.025,0.03,0.99)
  frame:SetBackdropBorderColor(0.25,0.25,0.28,1)
end

local function MakeText(parent, template, text)
  local value = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  value:SetText(text or "")
  return value
end

local function MakeCheck(parent, label, x, y)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetWidth(22); check:SetHeight(22)
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  check.text = MakeText(parent, "GameFontNormalSmall", label)
  check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  return check
end

local function Contains(values, wanted)
  if type(values) ~= "table" then return false end
  for _, value in ipairs(values) do if value == wanted then return true end end
  return false
end

local function NextValue(values, current)
  local index = 1
  for i, value in ipairs(values) do if value == current then index = i break end end
  index = index + 1
  if index > #values then index = 1 end
  return values[index]
end

local function ExistingTypes(existing, item)
  if existing then
    if type(existing.trackingTypes) == "table" and #existing.trackingTypes > 0 then return existing.trackingTypes end
    if type(existing.trackingType) == "string" and existing.trackingType ~= "" then return {existing.trackingType} end
  end
  if type(item.trackingTypes) == "table" and #item.trackingTypes > 0 then return item.trackingTypes end
  return {"cooldown"}
end

local function DefaultSetting(existing, key, fallback)
  if existing and type(existing.settings) == "table" and existing.settings[key] ~= nil then return existing.settings[key] end
  return fallback
end

local function CollectTypes(frame)
  local result = {}
  for _, option in ipairs(TYPE_OPTIONS) do
    local key = option[1]
    local check = frame.typeChecks[key]
    if check and check:GetChecked() then result[#result + 1] = key end
  end
  return result
end

local function RefreshSummary(frame)
  if not frame then return end
  local types = CollectTypes(frame)
  if #types == 0 then
    frame.summary:SetText("Choose at least one tracking type.")
    frame.save:Disable()
  else
    frame.summary:SetText("Track: |cffffffff"..table.concat(types, " + ").."|r  •  Unit: |cffffffff"..(UNIT_LABELS[frame.unit] or frame.unit).."|r  •  Display: |cffffffff"..(DISPLAY_LABELS[frame.display] or frame.display).."|r")
    frame.save:Enable()
  end
  frame.unitButton:SetText("Unit: " .. (UNIT_LABELS[frame.unit] or frame.unit))
  frame.displayButton:SetText("Display: " .. (DISPLAY_LABELS[frame.display] or frame.display))
  frame.sizeText:SetText("Icon size: " .. tostring(frame.iconSize))
  frame.glowButton:SetText("Glow: " .. (GLOW_LABELS[frame.glow] or frame.glow))
end

local function CreateEditor(self)
  if self.trackerEditorFrame then return self.trackerEditorFrame end
  if type(CreateFrame) ~= "function" or not UIParent then return nil end

  local frame = CreateFrame("Frame", "RetreatUITrackerEditor", UIParent)
  frame:SetWidth(560); frame:SetHeight(535)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
  frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
  Backdrop(frame)

  frame.title = MakeText(frame, "GameFontNormalLarge", "Configure Tracker")
  frame.title:SetPoint("TOPLEFT", 22, -20)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() frame:Hide() end)

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetWidth(44); frame.icon:SetHeight(44)
  frame.icon:SetPoint("TOPLEFT", 24, -58)

  frame.spellName = MakeText(frame, "GameFontNormal", "")
  frame.spellName:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
  frame.spellName:SetWidth(430); frame.spellName:SetJustifyH("LEFT")

  frame.spellMeta = MakeText(frame, "GameFontHighlightSmall", "")
  frame.spellMeta:SetPoint("TOPLEFT", frame.spellName, "BOTTOMLEFT", 0, -5)
  frame.spellMeta:SetWidth(430); frame.spellMeta:SetJustifyH("LEFT")

  frame.trackLabel = MakeText(frame, "GameFontNormal", "What should this tracker watch?")
  frame.trackLabel:SetPoint("TOPLEFT", 24, -120)
  frame.trackHint = MakeText(frame, "GameFontHighlightSmall", "Suggested types are preselected. You can combine multiple types.")
  frame.trackHint:SetPoint("TOPLEFT", frame.trackLabel, "BOTTOMLEFT", 0, -4)

  frame.typeChecks = {}
  for index, option in ipairs(TYPE_OPTIONS) do
    local column = ((index - 1) % 2)
    local row = math.floor((index - 1) / 2)
    local check = MakeCheck(frame, option[2], 24 + (column * 250), -157 - (row * 29))
    check.typeKey = option[1]
    check:SetScript("OnClick", function() RefreshSummary(frame) end)
    frame.typeChecks[option[1]] = check
  end

  frame.settingsLabel = MakeText(frame, "GameFontNormal", "Display & conditions")
  frame.settingsLabel:SetPoint("TOPLEFT", 24, -286)

  frame.unitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.unitButton:SetWidth(155); frame.unitButton:SetHeight(24); frame.unitButton:SetPoint("TOPLEFT", 24, -315)
  frame.unitButton:SetScript("OnClick", function()
    frame.unit = NextValue(UNITS, frame.unit)
    RefreshSummary(frame)
  end)

  frame.displayButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.displayButton:SetWidth(155); frame.displayButton:SetHeight(24); frame.displayButton:SetPoint("LEFT", frame.unitButton, "RIGHT", 12, 0)
  frame.displayButton:SetScript("OnClick", function()
    frame.display = NextValue(DISPLAYS, frame.display)
    RefreshSummary(frame)
  end)

  frame.glowButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.glowButton:SetWidth(180); frame.glowButton:SetHeight(24); frame.glowButton:SetPoint("LEFT", frame.displayButton, "RIGHT", 12, 0)
  frame.glowButton:SetScript("OnClick", function()
    frame.glow = NextValue(GLOWS, frame.glow)
    RefreshSummary(frame)
  end)

  frame.sizeMinus = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.sizeMinus:SetWidth(28); frame.sizeMinus:SetHeight(22); frame.sizeMinus:SetPoint("TOPLEFT", 24, -351); frame.sizeMinus:SetText("-")
  frame.sizeText = MakeText(frame, "GameFontHighlightSmall", "Icon size: 36")
  frame.sizeText:SetPoint("LEFT", frame.sizeMinus, "RIGHT", 8, 0)
  frame.sizePlus = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.sizePlus:SetWidth(28); frame.sizePlus:SetHeight(22); frame.sizePlus:SetPoint("LEFT", frame.sizeText, "RIGHT", 8, 0); frame.sizePlus:SetText("+")
  frame.sizeMinus:SetScript("OnClick", function() frame.iconSize = math.max(20, (frame.iconSize or 36) - 2); RefreshSummary(frame) end)
  frame.sizePlus:SetScript("OnClick", function() frame.iconSize = math.min(80, (frame.iconSize or 36) + 2); RefreshSummary(frame) end)

  frame.cooldownText = MakeCheck(frame, "Cooldown text", 24, -384)
  frame.duration = MakeCheck(frame, "Duration", 185, -384)
  frame.stacks = MakeCheck(frame, "Stacks / charges", 330, -384)
  frame.learnedOnly = MakeCheck(frame, "Only when learned", 24, -416)
  frame.combatOnly = MakeCheck(frame, "Combat only", 185, -416)

  frame.summary = MakeText(frame, "GameFontHighlightSmall", "")
  frame.summary:SetPoint("BOTTOMLEFT", 24, 72)
  frame.summary:SetWidth(510); frame.summary:SetJustifyH("LEFT")

  frame.safety = MakeText(frame, "GameFontDisableSmall", "Data-only test: this editor does not create or modify WeakAuras.")
  frame.safety:SetPoint("BOTTOMLEFT", 24, 52)

  frame.remove = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.remove:SetWidth(100); frame.remove:SetHeight(26); frame.remove:SetPoint("BOTTOMLEFT", 24, 18); frame.remove:SetText("Remove")
  frame.remove:SetScript("OnClick", function()
    local item = frame.item
    if item then RUI:RemoveTrackerSelection(item.className, item.key) end
    frame:Hide()
    if RUI.RefreshTrackerBuilder then RUI:RefreshTrackerBuilder() end
  end)

  frame.cancel = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.cancel:SetWidth(100); frame.cancel:SetHeight(26); frame.cancel:SetPoint("BOTTOMRIGHT", -136, 18); frame.cancel:SetText("Cancel")
  frame.cancel:SetScript("OnClick", function() frame:Hide() end)

  frame.save = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.save:SetWidth(120); frame.save:SetHeight(26); frame.save:SetPoint("BOTTOMRIGHT", -12, 18); frame.save:SetText("Save Tracker")
  frame.save:SetScript("OnClick", function()
    local item = frame.item
    if not item then return end
    local types = CollectTypes(frame)
    if #types == 0 then return end
    local ok = RUI:SaveTrackerSelection(item, {
      trackingTypes = types,
      unit = frame.unit,
      display = frame.display,
      iconSize = frame.iconSize,
      glow = frame.glow,
      showCooldownText = frame.cooldownText:GetChecked() and true or false,
      showDuration = frame.duration:GetChecked() and true or false,
      showStacks = frame.stacks:GetChecked() and true or false,
      learnedOnly = frame.learnedOnly:GetChecked() and true or false,
      combatOnly = frame.combatOnly:GetChecked() and true or false,
    })
    if ok then
      frame:Hide()
      if RUI.RefreshTrackerBuilder then RUI:RefreshTrackerBuilder() end
    end
  end)

  frame:Hide()
  self.trackerEditorFrame = frame
  return frame
end

function RUI:OpenTrackerEditor(item)
  if type(item) ~= "table" or type(item.key) ~= "string" then return false end
  local frame = CreateEditor(self)
  if not frame then return false end
  local existing = self:GetTrackerSelection(item.className, item.key)
  local types = ExistingTypes(existing, item)

  frame.item = item
  frame.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  frame.spellName:SetText(item.name or "Unknown")
  frame.spellMeta:SetText((item.specialization or "Shared").."  •  "..(item.category or "Uncategorized").."  •  Spell ID "..tostring(item.spellID or "?"))

  for _, option in ipairs(TYPE_OPTIONS) do
    local key = option[1]
    frame.typeChecks[key]:SetChecked(Contains(types, key) and 1 or nil)
  end

  frame.unit = (existing and existing.unit) or item.defaultUnit or (Contains(types, "debuff") and "target" or "player")
  frame.display = DefaultSetting(existing, "display", Contains(types, "resource") and "bar" or "icon")
  frame.iconSize = tonumber(DefaultSetting(existing, "iconSize", 36)) or 36
  frame.glow = DefaultSetting(existing, "glow", "off")

  frame.cooldownText:SetChecked(DefaultSetting(existing, "showCooldownText", Contains(types, "cooldown") or Contains(types, "charges")) and 1 or nil)
  frame.duration:SetChecked(DefaultSetting(existing, "showDuration", Contains(types, "buff") or Contains(types, "proc") or Contains(types, "debuff") or Contains(types, "stacks")) and 1 or nil)
  frame.stacks:SetChecked(DefaultSetting(existing, "showStacks", Contains(types, "stacks") or Contains(types, "charges")) and 1 or nil)
  frame.learnedOnly:SetChecked(DefaultSetting(existing, "learnedOnly", true) and 1 or nil)
  frame.combatOnly:SetChecked(DefaultSetting(existing, "combatOnly", false) and 1 or nil)

  if existing then frame.remove:Show() else frame.remove:Hide() end
  frame.save:SetText(existing and "Save Changes" or "Add Tracker")
  RefreshSummary(frame)
  frame:Show()
  return true
end
