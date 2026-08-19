local RUI = RetreatUI
if not RUI then return end

local ROWS = 12
local ROW_HEIGHT = 42
local ALLOWED_TYPES = {
  cooldown=true, buff=true, proc=true, debuff=true, stacks=true,
  charges=true, resource=true, summon=true,
}
local ALLOWED_UNITS = {player=true, target=true, focus=true, pet=true}

local function EnsureState(self)
  RetreatUIDB = RetreatUIDB or {}
  RetreatUIDB.trackerBuilder = RetreatUIDB.trackerBuilder or {}
  local db = RetreatUIDB.trackerBuilder
  db.selected = db.selected or {}
  db.filters = db.filters or {learnedOnly=true, recommendedOnly=false, includeAdvanced=false, includeUntrackable=false}
  return db
end

local function ClassSelection(self, className)
  if type(className) ~= "string" or className == "" then return {} end
  local db = EnsureState(self)
  db.selected[className] = db.selected[className] or {}
  return db.selected[className]
end

local function AddType(result, seen, value)
  if type(value) ~= "string" or not ALLOWED_TYPES[value] or seen[value] then return end
  seen[value] = true
  result[#result + 1] = value
end

local function CleanTypes(values, fallback)
  local result, seen = {}, {}
  if type(values) == "table" then
    for _, value in ipairs(values) do AddType(result, seen, value) end
  elseif type(values) == "string" then
    AddType(result, seen, values)
  end
  if #result == 0 and type(fallback) == "table" then
    for _, value in ipairs(fallback) do AddType(result, seen, value) end
  end
  if #result == 0 then AddType(result, seen, "cooldown") end
  return result
end

local function HasType(types, value)
  for _, current in ipairs(types or {}) do if current == value then return true end end
  return false
end

local function TemplateForTypes(types)
  if HasType(types, "resource") then return "resource" end
  if HasType(types, "debuff") then return "debuff" end
  if HasType(types, "proc") and HasType(types, "stacks") then return "proc_stacks" end
  if HasType(types, "proc") then return "proc" end
  if HasType(types, "buff") and HasType(types, "stacks") then return "buff_stacks" end
  if HasType(types, "buff") and HasType(types, "cooldown") then return "cooldown_aura" end
  if HasType(types, "buff") then return "buff" end
  if HasType(types, "charges") then return "charges" end
  if HasType(types, "summon") then return "summon" end
  return "cooldown"
end

function RUI:GetSelectedTrackers(className)
  className = className or (self.GetDetectedClass and self:GetDetectedClass())
  local selected = ClassSelection(self, className)
  local result = {}
  for _, value in pairs(selected) do result[#result + 1] = value end
  table.sort(result, function(a,b) return tostring(a.name) < tostring(b.name) end)
  return result
end

function RUI:GetTrackerSelection(className, key)
  if type(key) ~= "string" or key == "" then return nil end
  return ClassSelection(self, className)[key]
end

function RUI:IsTrackerSelected(className, key)
  return self:GetTrackerSelection(className, key) ~= nil
end

function RUI:RemoveTrackerSelection(className, key)
  if type(className) ~= "string" or className == "" or type(key) ~= "string" or key == "" then return false end
  local selected = ClassSelection(self, className)
  if not selected[key] then return false end
  selected[key] = nil
  return true
end

function RUI:SaveTrackerSelection(item, config)
  if type(item) ~= "table" or type(item.key) ~= "string" or type(item.className) ~= "string" then
    return false, "invalid tracker item"
  end
  config = type(config) == "table" and config or {}
  local types = CleanTypes(config.trackingTypes, item.trackingTypes)
  local unit = ALLOWED_UNITS[config.unit] and config.unit or item.defaultUnit or "player"
  if not ALLOWED_UNITS[unit] then unit = "player" end

  local display = config.display == "bar" and "bar" or "icon"
  if HasType(types, "resource") and config.display == nil then display = "bar" end
  local iconSize = tonumber(config.iconSize) or 36
  iconSize = math.max(20, math.min(80, math.floor(iconSize + 0.5)))
  local glow = (config.glow == "ready" or config.glow == "active") and config.glow or "off"

  local selected = ClassSelection(self, item.className)
  selected[item.key] = {
    key = item.key,
    className = item.className,
    name = item.name,
    spellID = item.spellID,
    auraID = item.auraID,
    auraName = item.auraName,
    template = TemplateForTypes(types),
    unit = unit,
    trackingType = types[1], -- legacy compatibility for beta.22/.23 saved data
    trackingTypes = types,
    specialization = item.specialization,
    category = item.category,
    settings = {
      display = display,
      iconSize = iconSize,
      showCooldownText = config.showCooldownText ~= false,
      showDuration = config.showDuration ~= false,
      showStacks = config.showStacks == true,
      learnedOnly = config.learnedOnly ~= false,
      combatOnly = config.combatOnly == true,
      glow = glow,
    },
  }
  return true, selected[item.key]
end

-- Compatibility helper retained for any older caller. New UI uses the editor.
function RUI:ToggleTrackerSelection(item)
  if type(item) ~= "table" or type(item.key) ~= "string" or type(item.className) ~= "string" then return false end
  if self:IsTrackerSelected(item.className, item.key) then
    self:RemoveTrackerSelection(item.className, item.key)
    return false
  end
  self:SaveTrackerSelection(item, {trackingTypes=item.trackingTypes, unit=item.defaultUnit})
  return true
end

local function Backdrop(frame)
  if not frame or type(frame.SetBackdrop) ~= "function" then return end
  frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
  frame:SetBackdropColor(0.035,0.035,0.04,0.98)
  frame:SetBackdropBorderColor(0.16,0.16,0.18,1)
end

local function MakeCheck(parent, label, x, y, key)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  check:SetWidth(22); check:SetHeight(22)
  check.text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
  check.text:SetText(label)
  check.key = key
  return check
end

local function CreateBuilder(self)
  if self.trackerBuilderFrame then return self.trackerBuilderFrame end
  if type(CreateFrame) ~= "function" or not UIParent then return nil end

  local frame = CreateFrame("Frame", "RetreatUITrackerBuilder", UIParent)
  frame:SetWidth(690); frame:SetHeight(710)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
  frame:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
  Backdrop(frame)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -18)
  title:SetText("RetreatUI  •  Tracker Builder")
  frame.title = title

  local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
  subtitle:SetText("Choose abilities, then configure exactly what each tracker should watch.")
  frame.subtitle = subtitle

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function()
    if RUI.trackerEditorFrame then RUI.trackerEditorFrame:Hide() end
    frame:Hide()
  end)

  local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  search:SetAutoFocus(false); search:SetWidth(270); search:SetHeight(24)
  search:SetPoint("TOPLEFT", 20, -70)
  frame.search = search

  local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("BOTTOMLEFT", search, "TOPLEFT", 3, 3)
  searchLabel:SetText("Search name / ID / category")

  frame.learned = MakeCheck(frame, "Learned only", 315, -67, "learnedOnly")
  frame.recommended = MakeCheck(frame, "Recommended", 445, -67, "recommendedOnly")
  frame.advanced = MakeCheck(frame, "Advanced", 315, -94, "includeAdvanced")
  frame.allEntries = MakeCheck(frame, "All entries", 445, -94, "includeUntrackable")

  local classText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  classText:SetPoint("TOPLEFT", 20, -115)
  frame.classText = classText

  local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("TOPRIGHT", -20, -117)
  status:SetJustifyH("RIGHT")
  frame.status = status

  frame.rows = {}
  for index=1, ROWS do
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_HEIGHT); row:SetWidth(650)
    row:SetPoint("TOPLEFT", 20, -145 - ((index-1)*ROW_HEIGHT))
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetWidth(32); row.icon:SetHeight(32); row.icon:SetPoint("LEFT", 4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3)
    row.name:SetWidth(350); row.name:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.meta:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3)
    row.meta:SetWidth(430); row.meta:SetJustifyH("LEFT")

    row.toggle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.toggle:SetWidth(82); row.toggle:SetHeight(22); row.toggle:SetPoint("RIGHT", -3, 0)
    row.toggle:SetScript("OnClick", function()
      if not row.item then return end
      if type(RUI.OpenTrackerEditor) == "function" then
        RUI:OpenTrackerEditor(row.item)
      else
        RUI:ToggleTrackerSelection(row.item)
        RUI:RefreshTrackerBuilder()
      end
    end)
    row:SetScript("OnDoubleClick", function()
      if row.item and type(RUI.OpenTrackerEditor) == "function" then RUI:OpenTrackerEditor(row.item) end
    end)
    frame.rows[index] = row
  end

  frame.prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.prev:SetWidth(90); frame.prev:SetHeight(24); frame.prev:SetPoint("BOTTOMLEFT", 20, 18); frame.prev:SetText("Previous")
  frame.next = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.next:SetWidth(90); frame.next:SetHeight(24); frame.next:SetPoint("LEFT", frame.prev, "RIGHT", 8, 0); frame.next:SetText("Next")
  frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.pageText:SetPoint("LEFT", frame.next, "RIGHT", 12, 0)

  frame.prev:SetScript("OnClick", function() frame.page = math.max(1, (frame.page or 1)-1); RUI:RefreshTrackerBuilder() end)
  frame.next:SetScript("OnClick", function() frame.page = (frame.page or 1)+1; RUI:RefreshTrackerBuilder() end)

  local function RefreshFromFilter()
    frame.page = 1
    RUI:RefreshTrackerBuilder()
  end
  search:SetScript("OnTextChanged", RefreshFromFilter)
  frame.recommended:SetScript("OnClick", function()
    if frame.recommended:GetChecked() then frame.learned:SetChecked(1) end
    RefreshFromFilter()
  end)
  frame.learned:SetScript("OnClick", function()
    if not frame.learned:GetChecked() and frame.recommended:GetChecked() then frame.recommended:SetChecked(nil) end
    RefreshFromFilter()
  end)
  frame.advanced:SetScript("OnClick", RefreshFromFilter)
  frame.allEntries:SetScript("OnClick", RefreshFromFilter)

  frame:Hide()
  self.trackerBuilderFrame = frame
  return frame
end

function RUI:RefreshTrackerBuilder()
  local frame = self.trackerBuilderFrame
  if not frame then return end
  local db = EnsureState(self)
  local filters = db.filters
  if frame.recommended:GetChecked() then frame.learned:SetChecked(1) end
  filters.learnedOnly = frame.learned:GetChecked() and true or false
  filters.recommendedOnly = frame.recommended:GetChecked() and true or false
  filters.includeAdvanced = frame.advanced:GetChecked() and true or false
  filters.includeUntrackable = frame.allEntries:GetChecked() and true or false

  local className = self.GetDetectedClass and self:GetDetectedClass() or "Unknown"
  frame.classText:SetText("Class: |cffffffff"..tostring(className).."|r")
  local catalog = self:GetTrackerCatalog(className, {
    query=frame.search:GetText() or "", learnedOnly=filters.learnedOnly, recommendedOnly=filters.recommendedOnly,
    includeAdvanced=filters.includeAdvanced, includeUntrackable=filters.includeUntrackable,
  })
  frame.catalog = catalog

  local selectedCount = #self:GetSelectedTrackers(className)
  frame.status:SetText(tostring(#catalog).." shown  •  "..tostring(selectedCount).." selected")

  local pages = math.max(1, math.ceil(#catalog / ROWS))
  frame.page = math.min(math.max(1, frame.page or 1), pages)
  frame.pageText:SetText("Page "..frame.page.." / "..pages)
  if frame.page <= 1 then frame.prev:Disable() else frame.prev:Enable() end
  if frame.page >= pages then frame.next:Disable() else frame.next:Enable() end

  for index,row in ipairs(frame.rows) do
    local item = catalog[((frame.page-1)*ROWS)+index]
    row.item = item
    if item then
      row:Show()
      row.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      row.name:SetText(item.name or "Unknown")
      local selected = self:GetTrackerSelection(className, item.key)
      local shownTypes = selected and selected.trackingTypes or item.trackingTypes
      if type(shownTypes) ~= "table" and selected and selected.trackingType then shownTypes = {selected.trackingType} end
      local kind = table.concat(shownTypes or {}, " + ")
      if kind == "" then kind = "choose type" end
      row.meta:SetText((item.specialization or "Shared").."  •  "..(item.category or "Uncategorized").."  •  ID "..tostring(item.spellID or "?").."  •  "..kind)
      row.toggle:SetText(selected and "Edit" or "Add")
    else
      row:Hide()
    end
  end
end

function RUI:OpenTrackerBuilder()
  local frame = CreateBuilder(self)
  if not frame then return false end
  local filters = EnsureState(self).filters
  if filters.recommendedOnly then filters.learnedOnly = true end
  frame.learned:SetChecked(filters.learnedOnly and 1 or nil)
  frame.recommended:SetChecked(filters.recommendedOnly and 1 or nil)
  frame.advanced:SetChecked(filters.includeAdvanced and 1 or nil)
  frame.allEntries:SetChecked(filters.includeUntrackable and 1 or nil)
  frame.page = 1
  self:RefreshTrackerBuilder()
  frame:Show()
  return true
end

function RUI:ToggleTrackerBuilder()
  local frame = CreateBuilder(self)
  if not frame then return false end
  if frame:IsShown() then
    if self.trackerEditorFrame then self.trackerEditorFrame:Hide() end
    frame:Hide()
    return false
  end
  return self:OpenTrackerBuilder()
end
